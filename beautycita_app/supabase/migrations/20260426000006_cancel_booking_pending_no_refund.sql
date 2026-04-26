-- =============================================================================
-- cancel_booking: pending payment_status must NOT trigger a refund
-- =============================================================================
-- Bug found via BC Monitor "Cancel: pending card booking" test (2026-04-26):
-- When a card/oxxo booking is created with create_booking_with_financials,
-- it starts at payment_status='pending' until the Stripe webhook fires. If
-- the user cancels in that window, the prior cancel_booking branched into
-- the free-cancel/late-cancel logic and credited (price - commission) MXN
-- to their saldo — phantom money, since Stripe never charged the card.
--
-- Fix: include 'pending' in the no-refund list alongside unpaid/expired/failed.
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

  -- 'pending' added: card/oxxo bookings sit in pending until Stripe webhook
  -- fires payment_intent.succeeded → 'paid'. Cancelling before that means
  -- BC never charged anything, so refund_amount must be 0.
  IF v_booking.payment_status IN ('unpaid', 'expired', 'failed', 'pending') THEN
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

COMMENT ON FUNCTION public.cancel_booking(uuid, text) IS
  'Cancel a booking. Refund=0 for unpaid/expired/failed/pending payment_status (no money moved). Card/oxxo bookings start in pending until Stripe webhook fires.';
