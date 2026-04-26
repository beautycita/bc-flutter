-- =============================================================================
-- Gate cancel_booking + purchase_product_with_saldo for is_test businesses
-- =============================================================================
-- Build 60110's test_business_isolation migration installed BEFORE-INSERT
-- triggers on tax_withholdings + commission_records that reject writes when
-- business.is_test = true. create_booking_with_financials was patched to skip
-- those writes gracefully for fixture businesses, but cancel_booking and
-- purchase_product_with_saldo were not — every checkup-APK run that lands on
-- a fixture (which is the entire prod salon list right now) aborts mid-RPC.
--
-- This migration adds the same NOT v_biz_is_test guard to both RPCs and
-- makes salon_debts also skip for fixtures (no SAT exposure but keeps the
-- ledger clean and avoids confusing reconciliation reports).
--
-- Behavior on a real (non-test) business is unchanged. is_test rows will
-- still get the appointment / order written so the test exercises the code
-- path; only the SAT-visible / commission-record side effects are bypassed.
-- =============================================================================

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
  SELECT * INTO v_booking
  FROM appointments
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking no encontrado: %', p_booking_id;
  END IF;

  IF v_booking.status IN ('cancelled_customer', 'cancelled_business') THEN
    RETURN jsonb_build_object(
      'already_cancelled', true,
      'refund_amount', 0,
      'status', v_booking.status,
      'commission_kept', 0,
      'seller_debt_created', 0
    );
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

  -- Fixture businesses bypass SAT-visible side effects.
  IF v_booking.business_id IS NOT NULL THEN
    SELECT COALESCE(is_test, false) INTO v_biz_is_test
      FROM businesses WHERE id = v_booking.business_id;
  END IF;

  IF COALESCE(v_booking.booking_source, 'bc_marketplace') = 'bc_marketplace' THEN
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

  -- Saldo refund happens regardless of is_test so the test path exercises it.
  IF v_refund_amount > 0 THEN
    PERFORM increment_saldo(
      v_booking.user_id,
      v_refund_amount,
      'cancellation_refund',
      'cancel:' || p_booking_id::text
    );
  END IF;

  -- salon_debts + reverse_tax_withholding + commission_records are all
  -- ledger-side effects that fixtures must not produce. The trigger would
  -- block tax + commission anyway; salon_debts has no trigger but we keep
  -- the ledger clean either way.
  IF v_refund_amount > 0 AND v_booking.business_id IS NOT NULL AND NOT v_biz_is_test THEN
    INSERT INTO salon_debts (
      business_id, appointment_id, original_amount, remaining_amount,
      reason, source, created_at
    ) VALUES (
      v_booking.business_id, v_booking.id, v_refund_amount, v_refund_amount,
      'refund_cancelled_booking', 'booking_refund', now()
    )
    ON CONFLICT DO NOTHING;

    PERFORM reverse_tax_withholding(
      p_appointment_id := v_booking.id,
      p_reason := 'cancellation'
    );
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
  SET status = v_cancel_status,
      payment_status = v_payment_status,
      refund_amount = v_refund_amount,
      refunded_at = CASE WHEN v_refund_amount > 0 THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'already_cancelled', false,
    'refund_amount', v_refund_amount,
    'status', v_cancel_status,
    'commission_kept', v_bc_commission,
    'seller_debt_created', CASE WHEN v_refund_amount > 0 AND NOT v_biz_is_test THEN v_refund_amount ELSE 0 END,
    'is_test_business', v_biz_is_test
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.purchase_product_with_saldo(
  p_user_id uuid,
  p_business_id uuid,
  p_product_id uuid,
  p_product_name text,
  p_quantity integer,
  p_total_amount numeric,
  p_shipping_address jsonb DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_saldo           numeric;
  v_commission_rate numeric;
  v_commission      numeric;
  v_order_id        uuid;
  v_existing        uuid;
  v_biz_is_test     boolean := false;
BEGIN
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing
    FROM public.orders
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      RETURN jsonb_build_object(
        'order_id', v_existing::text,
        'commission', 0,
        'already_existed', true
      );
    END IF;
  ELSE
    SELECT id INTO v_existing
    FROM public.orders
    WHERE buyer_id = p_user_id
      AND product_id = p_product_id
      AND status <> 'cancelled'
      AND idempotency_key IS NULL
      AND created_at > now() - interval '5 minutes'
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      RETURN jsonb_build_object(
        'order_id', v_existing::text,
        'commission', 0,
        'already_existed', true
      );
    END IF;
  END IF;

  v_commission_rate := get_config_rate('commission_rate_product', 0.10);
  v_commission := ROUND(p_total_amount * v_commission_rate, 2);

  -- Skip commission ledger writes for fixture businesses (the trigger would
  -- block them anyway; this avoids a mid-tx exception that would force a
  -- rollback of saldo deduction + order insert).
  SELECT COALESCE(is_test, false) INTO v_biz_is_test
    FROM public.businesses WHERE id = p_business_id;

  SELECT saldo INTO v_saldo
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_saldo IS NULL THEN
    RAISE EXCEPTION 'Usuario no encontrado';
  END IF;

  IF v_saldo < p_total_amount THEN
    RAISE EXCEPTION 'Saldo insuficiente (% < %)', v_saldo, p_total_amount;
  END IF;

  UPDATE public.profiles
  SET saldo = saldo - p_total_amount, updated_at = now()
  WHERE id = p_user_id;

  INSERT INTO public.orders (
    buyer_id, business_id, product_id, product_name, quantity,
    total_amount, commission_amount, status, payment_method,
    shipping_address, idempotency_key
  ) VALUES (
    p_user_id, p_business_id, p_product_id, p_product_name, p_quantity,
    p_total_amount, v_commission, 'paid', 'saldo',
    p_shipping_address, p_idempotency_key
  )
  RETURNING id INTO v_order_id;

  IF NOT v_biz_is_test THEN
    INSERT INTO public.commission_records (
      business_id, order_id, amount, rate, source,
      period_month, period_year, status
    ) VALUES (
      p_business_id, v_order_id, v_commission, v_commission_rate, 'product_sale',
      EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
    );
  END IF;

  RETURN jsonb_build_object(
    'order_id', v_order_id::text,
    'commission', v_commission,
    'commission_rate', v_commission_rate,
    'is_test_business', v_biz_is_test,
    'already_existed', false
  );
END;
$$;

COMMENT ON FUNCTION public.cancel_booking IS
  'Cancel an appointment and process the refund idempotently. For is_test '
  'businesses, skips salon_debts + tax-reversal + commission writes (the '
  'BEFORE-INSERT triggers would otherwise abort the RPC). Saldo refund and '
  'appointment status update still run so the code path is exercised.';

COMMENT ON FUNCTION public.purchase_product_with_saldo IS
  'Saldo-paid product purchase with idempotency. For is_test businesses, '
  'skips the commission_records INSERT (test_business_isolation trigger '
  'would block it). Order row + saldo deduction still happen.';
