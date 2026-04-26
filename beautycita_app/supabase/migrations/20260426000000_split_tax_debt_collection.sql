-- =============================================================================
-- Tax debt vs other debt: separate collection priority
-- =============================================================================
-- Policy split (Kriket 2026-04-26):
--   * Tax debt (BC owes SAT, salon owes BC for it) → collect 100% of next
--     payout immediately until extinguished. SAT can't wait.
--   * All other debt (refund chargebacks, commission owed, overdrafts) →
--     50%-of-net-payout cap. Stylist always takes home at least half.
--
-- Plus: ExpressCita with payment_method='cash_direct' becomes ON-NETWORK.
-- BC didn't physically receive the cash but the appointment lives on BC's
-- platform under the digital-intermediation regime, so BC owes SAT for the
-- tax retention. The salon owes BC both the tax retention amount AND the 3%
-- commission. Two salon_debts rows per cash-ExpressCita booking.
-- =============================================================================

-- ── 1. Add 'tax_obligation' to debt_type CHECK ─────────────────────────────
ALTER TABLE salon_debts DROP CONSTRAINT IF EXISTS salon_debts_debt_type_check;
ALTER TABLE salon_debts ADD CONSTRAINT salon_debts_debt_type_check
  CHECK (debt_type IN (
    'tax_obligation',                 -- ISR/IVA owed to SAT, must be collected 100%
    'operational_commission',         -- BC commission salon owes (cash payment)
    'operational_refund_pos',         -- refund chargeback (POS / cancellation)
    'operational_saldo_overdraft',    -- saldo went negative
    'pursued_doubtful'                -- write-off pursued via collections
  ));

COMMENT ON COLUMN salon_debts.debt_type IS
  'tax_obligation = SAT pass-through (100% next payout). Other types = 50% cap.';

CREATE INDEX IF NOT EXISTS idx_salon_debts_tax_first
  ON salon_debts (business_id, created_at)
  WHERE remaining_amount > 0 AND debt_type = 'tax_obligation';

-- ── 2. Two-tier calculate_payout_with_debt ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.calculate_payout_with_debt(
  p_business_id    uuid,
  p_gross_amount   numeric,
  p_commission     numeric,
  p_iva_withheld   numeric,
  p_isr_withheld   numeric
)
RETURNS TABLE(salon_payout numeric, debt_collected numeric, remaining_debt numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_net numeric;
  v_tax_debt numeric;
  v_other_debt numeric;
  v_tax_collected numeric := 0;
  v_other_collected numeric := 0;
  v_other_cap numeric;
  v_other_actual numeric;
  v_remaining_to_collect numeric;
  v_debt_record record;
BEGIN
  IF public.has_active_payout_hold(p_business_id) THEN
    RAISE EXCEPTION 'PAYOUT_HOLD_ACTIVE: %', p_business_id;
  END IF;

  v_net := p_gross_amount - p_commission - p_iva_withheld - p_isr_withheld;
  IF v_net < 0 THEN v_net := 0; END IF;

  -- Bucket totals
  SELECT COALESCE(SUM(remaining_amount), 0) INTO v_tax_debt
    FROM salon_debts
   WHERE business_id = p_business_id
     AND remaining_amount > 0
     AND debt_type = 'tax_obligation';

  SELECT COALESCE(SUM(remaining_amount), 0) INTO v_other_debt
    FROM salon_debts
   WHERE business_id = p_business_id
     AND remaining_amount > 0
     AND debt_type <> 'tax_obligation';

  IF v_tax_debt + v_other_debt <= 0 THEN
    salon_payout := v_net;
    debt_collected := 0;
    remaining_debt := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  -- TIER 1: tax debt — 100% of net, FIFO, capped by tax debt total + remaining net
  v_tax_collected := LEAST(v_tax_debt, v_net);
  v_remaining_to_collect := v_tax_collected;
  IF v_remaining_to_collect > 0 THEN
    FOR v_debt_record IN
      SELECT id, remaining_amount FROM salon_debts
       WHERE business_id = p_business_id
         AND remaining_amount > 0
         AND debt_type = 'tax_obligation'
       ORDER BY created_at ASC
    LOOP
      EXIT WHEN v_remaining_to_collect <= 0;
      DECLARE
        v_apply numeric := LEAST(v_remaining_to_collect, v_debt_record.remaining_amount);
      BEGIN
        UPDATE salon_debts
           SET remaining_amount = remaining_amount - v_apply,
               cleared_at = CASE WHEN remaining_amount - v_apply = 0 THEN now() ELSE NULL END
         WHERE id = v_debt_record.id;
        v_remaining_to_collect := v_remaining_to_collect - v_apply;
      END;
    END LOOP;
  END IF;

  -- TIER 2: other debt — 50% of NET, after tax has been collected
  -- (the 50% cap applies to net, not net-minus-tax — tax always gets 100% first
  -- but the salon floor is 50% of remaining net AFTER tax collection)
  DECLARE
    v_net_after_tax numeric := v_net - v_tax_collected;
  BEGIN
    v_other_cap := v_net_after_tax * 0.50;
    v_other_actual := LEAST(v_other_cap, v_other_debt, v_net_after_tax);
    v_remaining_to_collect := v_other_actual;
    IF v_remaining_to_collect > 0 THEN
      FOR v_debt_record IN
        SELECT id, remaining_amount FROM salon_debts
         WHERE business_id = p_business_id
           AND remaining_amount > 0
           AND debt_type <> 'tax_obligation'
         ORDER BY created_at ASC
      LOOP
        EXIT WHEN v_remaining_to_collect <= 0;
        DECLARE
          v_apply numeric := LEAST(v_remaining_to_collect, v_debt_record.remaining_amount);
        BEGIN
          UPDATE salon_debts
             SET remaining_amount = remaining_amount - v_apply,
                 cleared_at = CASE WHEN remaining_amount - v_apply = 0 THEN now() ELSE NULL END
           WHERE id = v_debt_record.id;
          v_remaining_to_collect := v_remaining_to_collect - v_apply;
        END;
      END LOOP;
    END IF;
    v_other_collected := v_other_actual;
  END;

  -- Refresh denorm cache
  UPDATE businesses
     SET outstanding_debt = (
       SELECT COALESCE(SUM(remaining_amount), 0) FROM salon_debts
        WHERE business_id = p_business_id AND remaining_amount > 0
     )
   WHERE id = p_business_id;

  salon_payout := v_net - v_tax_collected - v_other_collected;
  debt_collected := v_tax_collected + v_other_collected;
  remaining_debt := (v_tax_debt - v_tax_collected) + (v_other_debt - v_other_collected);
  RETURN NEXT;
  RETURN;
END;
$$;

COMMENT ON FUNCTION public.calculate_payout_with_debt(uuid, numeric, numeric, numeric, numeric) IS
  'Two-tier debt collection: tax_obligation collected 100% first, all other debt at 50% of remaining net (FIFO within each tier). Guarded by has_active_payout_hold().';

-- ── 3. cancel_booking: set debt_type='operational_refund_pos' on its INSERT ─
-- Currently it doesn't pass debt_type, so the column defaults to
-- 'operational_commission' — which would put refund debt under the wrong
-- bucket and is_test gating already in place.
CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id uuid,
  p_cancelled_by text DEFAULT 'customer'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking        RECORD;
  v_cancel_status  text;
  v_refund_amount  numeric;
  v_bc_commission  numeric;
  v_commission_rate numeric;
  v_deposit_amount numeric := 0;
  v_hours_until    numeric;
  v_free_cancel_window_hours numeric := 24;
  v_payment_status text;
  v_biz_is_test    boolean := false;
BEGIN
  SELECT * INTO v_booking FROM appointments WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking no encontrado: %', p_booking_id;
  END IF;
  IF v_booking.status IN ('cancelled_customer', 'cancelled_business') THEN
    RETURN jsonb_build_object('already_cancelled', true, 'refund_amount', 0,
      'status', v_booking.status, 'commission_kept', 0, 'seller_debt_created', 0);
  END IF;

  IF p_cancelled_by = 'customer' THEN
    IF v_booking.starts_at < now() THEN
      RAISE EXCEPTION 'No se puede cancelar una cita que ya paso';
    END IF;
    v_cancel_status := 'cancelled_customer';
  ELSIF p_cancelled_by = 'business' THEN
    v_cancel_status := 'cancelled_business';
  ELSE
    RAISE EXCEPTION 'cancelled_by invalido: %', p_cancelled_by;
  END IF;

  v_hours_until := EXTRACT(EPOCH FROM (v_booking.starts_at - now())) / 3600;
  v_deposit_amount := COALESCE(v_booking.deposit_amount, 0);

  IF v_booking.business_id IS NOT NULL THEN
    SELECT COALESCE(is_test, false) INTO v_biz_is_test
      FROM businesses WHERE id = v_booking.business_id;
  END IF;

  IF COALESCE(v_booking.booking_source, 'bc_marketplace') IN ('bc_marketplace','invite_link','cita_express') THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;
  v_bc_commission := ROUND(v_booking.price * v_commission_rate, 2);

  IF v_booking.payment_status IN ('unpaid', 'expired', 'failed') THEN
    v_refund_amount := 0;
    v_bc_commission := 0;
    v_payment_status := v_booking.payment_status;
  ELSIF p_cancelled_by = 'business' THEN
    v_refund_amount := v_booking.price;
    v_payment_status := 'refunded_to_saldo';
  ELSIF v_hours_until >= v_free_cancel_window_hours THEN
    v_refund_amount := v_booking.price - v_bc_commission;
    v_payment_status := 'refunded_to_saldo';
  ELSIF v_deposit_amount > 0 THEN
    v_refund_amount := GREATEST(v_booking.price - v_deposit_amount - v_bc_commission, 0);
    v_payment_status := 'refunded_to_saldo';
  ELSE
    v_refund_amount := v_booking.price - v_bc_commission;
    v_payment_status := 'refunded_to_saldo';
  END IF;

  IF v_refund_amount > 0 THEN
    PERFORM increment_saldo(
      v_booking.user_id, v_refund_amount,
      'cancellation_refund', 'cancel:' || p_booking_id::text
    );
  END IF;

  IF v_refund_amount > 0 AND v_booking.business_id IS NOT NULL AND NOT v_biz_is_test THEN
    INSERT INTO salon_debts (
      business_id, appointment_id, original_amount, remaining_amount,
      debt_type, reason, source, created_at
    ) VALUES (
      v_booking.business_id, v_booking.id, v_refund_amount, v_refund_amount,
      'operational_refund_pos', 'refund_cancelled_booking', 'booking_refund', now()
    )
    ON CONFLICT DO NOTHING;

    PERFORM reverse_tax_withholding(p_appointment_id := v_booking.id, p_reason := 'cancellation');
  END IF;

  IF v_bc_commission > 0 AND v_booking.business_id IS NOT NULL AND NOT v_biz_is_test THEN
    INSERT INTO commission_records (
      business_id, appointment_id, amount, rate, source,
      period_month, period_year, status, created_at
    ) VALUES (
      v_booking.business_id, v_booking.id, v_bc_commission, v_commission_rate,
      CASE WHEN p_cancelled_by = 'business' THEN 'salon_cancellation'
           ELSE 'customer_cancellation' END,
      EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int,
      'collected', now()
    )
    ON CONFLICT DO NOTHING;
  END IF;

  UPDATE appointments
  SET status = v_cancel_status, payment_status = v_payment_status,
      refund_amount = v_refund_amount,
      refunded_at = CASE WHEN v_refund_amount > 0 THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'already_cancelled', false, 'refund_amount', v_refund_amount,
    'status', v_cancel_status, 'commission_kept', v_bc_commission,
    'seller_debt_created', CASE WHEN v_refund_amount > 0 AND NOT v_biz_is_test THEN v_refund_amount ELSE 0 END,
    'is_test_business', v_biz_is_test
  );
END;
$$;

-- ── 4. ExpressCita cash → on-network with tax debt + commission debt ───────
-- create_booking_with_financials: extend on-network sources to include
-- 'cita_express'. When payment_method='cash_direct' on an on-network booking,
-- BC didn't receive the cash, so:
--   * tax_withholdings row IS written (BC owes SAT for the appointment)
--   * salon_debts(tax_obligation) row created for ISR + IVA (salon must
--     reimburse BC so BC can forward to SAT)
--   * commission_records row IS written (BC earned the commission)
--   * salon_debts(operational_commission) row created for the commission
--     amount (salon must reimburse BC since BC didn't get cash)
--
-- Card / saldo / OXXO on cita_express follow the normal on-network flow
-- (BC receives money → withholds tax → keeps commission → pays the rest).
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.create_booking_with_financials(
  p_user_id uuid, p_business_id uuid, p_service_id text, p_service_name text, p_service_type text,
  p_starts_at timestamp with time zone, p_ends_at timestamp with time zone, p_price numeric,
  p_payment_method text, p_booking_source text,
  p_transport_mode text DEFAULT NULL::text, p_staff_id uuid DEFAULT NULL::uuid,
  p_notes text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text,
  p_deposit_amount numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_booking_id       uuid;
  v_saldo            numeric;
  v_iva_inclusive     numeric;
  v_isr_rate         numeric;
  v_iva_rate         numeric;
  v_commission_rate  numeric;
  v_tax_base         numeric;
  v_iva_portion      numeric;
  v_isr_withheld     numeric;
  v_iva_withheld     numeric;
  v_provider_net     numeric;
  v_commission       numeric;
  v_platform_fee     numeric;
  v_status           text;
  v_payment_status   text;
  v_paid_at          timestamptz;
  v_biz_rfc          text;
  v_biz_tax_regime   text;
  v_biz_tax_residency text;
  v_biz_is_test      boolean;
  v_existing         jsonb;
  v_charge_amount    numeric;
  v_is_on_network    boolean;
  v_is_cash_on_net   boolean;
  v_tax_total        numeric;
BEGIN
  IF p_idempotency_key IS NOT NULL THEN
    SELECT jsonb_build_object(
      'booking_id', a.id::text, 'tax_base', a.tax_base, 'isr_withheld', a.isr_withheld,
      'iva_withheld', a.iva_withheld, 'provider_net', a.provider_net,
      'commission', a.platform_fee, 'deposit_amount', a.deposit_amount, 'already_existed', true
    ) INTO v_existing
    FROM public.appointments a
    WHERE a.user_id = p_user_id AND a.business_id = p_business_id
      AND a.service_id = NULLIF(p_service_id, '')::uuid
      AND a.starts_at = p_starts_at
      AND a.status NOT IN ('cancelled_customer', 'cancelled_business')
    LIMIT 1;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  IF p_deposit_amount < 0 THEN RAISE EXCEPTION 'deposit_amount no puede ser negativo'; END IF;
  IF p_deposit_amount > p_price THEN RAISE EXCEPTION 'deposit_amount (%) excede el precio (%)', p_deposit_amount, p_price; END IF;

  v_iva_inclusive := get_config_rate('iva_inclusive_rate', 1.16);
  SELECT rfc, COALESCE(is_test, false) INTO v_biz_rfc, v_biz_is_test
    FROM public.businesses WHERE id = p_business_id;

  IF v_biz_rfc IS NOT NULL AND v_biz_rfc != '' THEN
    v_isr_rate := get_config_rate('isr_rate', 0.025);
    v_iva_rate := get_config_rate('iva_rate', 0.08);
  ELSE
    v_isr_rate := get_config_rate('isr_rate_no_rfc', 0.20);
    v_iva_rate := get_config_rate('iva_rate_no_rfc', 0.16);
  END IF;

  -- on-network now includes 'cita_express'
  v_is_on_network := p_booking_source IN ('bc_marketplace', 'invite_link', 'cita_express');

  IF v_is_on_network THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;

  v_tax_base    := ROUND(p_price / v_iva_inclusive, 2);
  v_iva_portion := ROUND(p_price - v_tax_base, 2);
  v_isr_withheld := ROUND(p_price * v_isr_rate, 2);
  v_iva_withheld := ROUND(v_iva_portion * v_iva_rate, 2);
  v_commission   := ROUND(p_price * v_commission_rate, 2);
  v_platform_fee := v_commission;
  v_provider_net := GREATEST(ROUND(p_price - v_isr_withheld - v_iva_withheld, 2), 0);

  SELECT tax_regime, tax_residency
    INTO v_biz_tax_regime, v_biz_tax_residency
    FROM public.businesses WHERE id = p_business_id;

  v_charge_amount := CASE WHEN p_deposit_amount > 0 THEN p_deposit_amount ELSE p_price END;

  IF p_payment_method = 'saldo' THEN
    SELECT saldo INTO v_saldo FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    IF v_saldo IS NULL THEN RAISE EXCEPTION 'Usuario no encontrado'; END IF;
    IF v_saldo < v_charge_amount THEN RAISE EXCEPTION 'Saldo insuficiente (% < %)', v_saldo, v_charge_amount; END IF;
    UPDATE public.profiles SET saldo = saldo - v_charge_amount, updated_at = now() WHERE id = p_user_id;
    v_status := 'confirmed';
    v_payment_status := CASE WHEN p_deposit_amount > 0 THEN 'deposit_paid' ELSE 'paid' END;
    v_paid_at := now();

  ELSIF p_payment_method = 'cash_direct' THEN
    IF p_deposit_amount > 0 THEN
      RAISE EXCEPTION 'cash_direct no puede tener deposito; use saldo o card para el deposito';
    END IF;
    v_status := 'confirmed';
    v_payment_status := 'paid';
    v_paid_at := now();

  ELSIF p_payment_method IN ('card', 'oxxo') THEN
    v_status := 'pending';
    v_payment_status := 'pending';
    v_paid_at := NULL;

  ELSE
    RAISE EXCEPTION 'Metodo de pago no soportado: %', p_payment_method;
  END IF;

  v_is_cash_on_net := v_is_on_network AND p_payment_method = 'cash_direct';

  INSERT INTO public.appointments (
    user_id, business_id, service_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method,
    transport_mode, staff_id, notes, paid_at, booking_source,
    tax_base, isr_withheld, iva_withheld, provider_net, platform_fee, deposit_amount
  ) VALUES (
    p_user_id, p_business_id, NULLIF(p_service_id, '')::uuid, p_service_name, p_service_type,
    p_starts_at, p_ends_at, p_price, v_status, v_payment_status, p_payment_method,
    p_transport_mode, p_staff_id, p_notes, v_paid_at, p_booking_source,
    v_tax_base, v_isr_withheld, v_iva_withheld, v_provider_net, v_platform_fee, p_deposit_amount
  )
  RETURNING id INTO v_booking_id;

  -- Tax + commission ledger writes for ON-NETWORK non-test bookings
  IF v_is_on_network AND NOT v_biz_is_test THEN
    INSERT INTO public.tax_withholdings (
      appointment_id, business_id, payment_type,
      gross_amount, tax_base, iva_portion, platform_fee,
      isr_rate, iva_rate, isr_withheld, iva_withheld, provider_net,
      provider_rfc, provider_tax_regime, provider_tax_residency,
      period_year, period_month
    ) VALUES (
      v_booking_id, p_business_id, p_payment_method,
      p_price, v_tax_base, v_iva_portion, v_platform_fee,
      v_isr_rate, v_iva_rate, v_isr_withheld, v_iva_withheld, v_provider_net,
      v_biz_rfc, v_biz_tax_regime, COALESCE(v_biz_tax_residency, 'MX'),
      EXTRACT(YEAR FROM now())::int, EXTRACT(MONTH FROM now())::int
    );

    IF v_commission > 0 THEN
      INSERT INTO public.commission_records (
        business_id, appointment_id, amount, rate, source,
        period_month, period_year, status
      ) VALUES (
        p_business_id, v_booking_id, v_commission, v_commission_rate, 'appointment',
        EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
      );
    END IF;

    -- ExpressCita-cash: BC didn't get the money. Salon owes BC for tax pass-
    -- through AND for the commission BC earned but couldn't withhold from cash.
    IF v_is_cash_on_net THEN
      v_tax_total := v_isr_withheld + v_iva_withheld;
      IF v_tax_total > 0 THEN
        INSERT INTO salon_debts (
          business_id, appointment_id, original_amount, remaining_amount,
          debt_type, reason, source, created_at
        ) VALUES (
          p_business_id, v_booking_id, v_tax_total, v_tax_total,
          'tax_obligation', 'cash_express_cita_tax_pass_through',
          'cita_express_cash', now()
        );
      END IF;
      IF v_commission > 0 THEN
        INSERT INTO salon_debts (
          business_id, appointment_id, original_amount, remaining_amount,
          debt_type, reason, source, created_at
        ) VALUES (
          p_business_id, v_booking_id, v_commission, v_commission,
          'operational_commission', 'cash_express_cita_commission',
          'cita_express_cash', now()
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'booking_id', v_booking_id::text,
    'tax_base', v_tax_base, 'isr_withheld', v_isr_withheld,
    'iva_withheld', v_iva_withheld, 'provider_net', v_provider_net,
    'commission', v_commission, 'commission_rate', v_commission_rate,
    'deposit_amount', p_deposit_amount, 'charged_amount', v_charge_amount,
    'cash_due_at_salon', GREATEST(p_price - p_deposit_amount, 0),
    'saldo_deducted', (p_payment_method = 'saldo'),
    'is_test_business', v_biz_is_test,
    'cash_express_cita_debt_created', v_is_cash_on_net,
    'already_existed', false
  );
END;
$function$;
