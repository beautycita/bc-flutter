-- =============================================================================
-- Fix: cancel_booking references nonexistent services.deposit_amount
-- =============================================================================
-- Regression introduced in 20260420000000_saldo_idempotency_callers.sql:
-- the rewritten cancel_booking body reads `s.deposit_amount` from services,
-- but the services table only exposes `deposit_required` + `deposit_percentage`.
-- `deposit_amount` lives on the appointments row itself (stamped at book time),
-- so every cancel path has been returning
--   400 {"code":"42703","message":"column s.deposit_amount does not exist"}
-- since 2026-04-20. Caught by bughunter flow booking-create-and-cancel.
--
-- Fix 1: read v_booking.deposit_amount directly. v_booking is already loaded via
-- the initial FOR UPDATE SELECT, so we don't need a second lookup.
-- Fix 2: salon_debts INSERT was also wrong — the table uses original_amount +
-- remaining_amount (not "amount"), and has no "status" column. Column names
-- aligned with _shared/refund.ts and the 04-16 migration.
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

  -- Deposit is stamped on the appointment row at booking time. No service lookup needed.
  v_deposit_amount := COALESCE(v_booking.deposit_amount, 0);

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

  IF v_refund_amount > 0 THEN
    PERFORM increment_saldo(
      v_booking.user_id,
      v_refund_amount,
      'cancellation_refund',
      'cancel:' || p_booking_id::text
    );
  END IF;

  IF v_refund_amount > 0 AND v_booking.business_id IS NOT NULL THEN
    INSERT INTO salon_debts (
      business_id, appointment_id, original_amount, remaining_amount,
      reason, source, created_at
    ) VALUES (
      v_booking.business_id,
      v_booking.id,
      v_refund_amount,
      v_refund_amount,
      'refund_cancelled_booking',
      'booking_refund',
      now()
    )
    ON CONFLICT DO NOTHING;

    -- void-returning; use PERFORM, no assignment.
    PERFORM reverse_tax_withholding(
      p_appointment_id := v_booking.id,
      p_reason := 'cancellation'
    );
  END IF;

  IF v_bc_commission > 0 AND v_booking.business_id IS NOT NULL THEN
    INSERT INTO commission_records (
      business_id, appointment_id, amount, rate, source,
      period_month, period_year, status, created_at
    ) VALUES (
      v_booking.business_id,
      v_booking.id,
      v_bc_commission,
      v_commission_rate,
      CASE WHEN p_cancelled_by = 'business' THEN 'salon_cancellation'
           ELSE 'customer_cancellation' END,
      EXTRACT(MONTH FROM now())::int,
      EXTRACT(YEAR FROM now())::int,
      'collected',
      now()
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
    'seller_debt_created', CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE 0 END
  );
END;
$$;

COMMENT ON FUNCTION cancel_booking(uuid, text) IS
  'Cancel an appointment and process the refund idempotently. '
  'Reads deposit_amount from the appointment row (stamped at book time), '
  'not the services table. Idempotency key ''cancel:{booking_id}'' prevents '
  'saldo double-credit on retry.';
