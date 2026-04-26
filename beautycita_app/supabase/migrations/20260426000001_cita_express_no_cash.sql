-- =============================================================================
-- ExpressCita: prohibit cash, remove tax-debt-on-cash auto-population
-- =============================================================================
-- Policy decision (Kriket 2026-04-26):
--
-- ExpressCita is BC's branded walk-in widget. Because the appointment lives
-- on BC's platform under the digital-intermediation regime, BC has the SAT
-- tax-retention obligation for every ExpressCita booking. If the customer
-- pays cash directly to the salon, BC has the tax obligation but doesn't
-- have the money to retain — a structural mismatch. Yesterday's migration
-- (20260426000000) tried to bridge this with `tax_obligation` salon_debts
-- rows, but that creates a long-term collection problem for salons whose
-- only ExpressCita traffic is cash.
--
-- Cleaner fix: prohibit cash on ExpressCita. If the customer wants to pay
-- cash, they should use the salon's internal walk-in QR (qr-walkin-register),
-- which is off-network and the salon handles their own tax. ExpressCita
-- becomes saldo / card / OXXO only — money always flows through BC, BC
-- always has tax to retain.
--
-- The `tax_obligation` debt_type stays in the schema (for future edge cases
-- like late refunds after SAT-remit), but the auto-population path is
-- removed.
-- =============================================================================

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

  -- HARD BLOCK: ExpressCita cannot accept cash. BC has the SAT obligation
  -- for cita_express bookings; cash leaves us holding a tax debt with no
  -- direct collection path. If the customer wants to pay cash, route them
  -- through the salon's internal walk-in QR instead (off-network, salon-
  -- handled tax).
  IF p_booking_source = 'cita_express' AND p_payment_method = 'cash_direct' THEN
    RAISE EXCEPTION 'ExpressCita no acepta efectivo. Usa saldo, tarjeta u OXXO. Para pagar en efectivo, escanea el QR interno del salon.'
      USING ERRCODE = 'check_violation';
  END IF;

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

  -- Tax + commission ledger writes for ON-NETWORK non-test bookings.
  -- ExpressCita-cash path is now blocked above, so we never reach here with
  -- a cash on-network booking → no tax debt auto-population needed.
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
    'already_existed', false
  );
END;
$function$;
