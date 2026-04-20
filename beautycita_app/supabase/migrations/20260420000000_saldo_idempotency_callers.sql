-- =============================================================================
-- Saldo idempotency: patch the callers that were skipping p_idempotency_key
-- =============================================================================
--
-- Background: migration 20260410000002 added idempotency support to
-- increment_saldo (p_reason + p_idempotency_key with UNIQUE constraint on
-- saldo_ledger.idempotency_key). But three production callers were never
-- updated to use it:
--
--   1. cancel_booking RPC (refund branch) — migrations 20260407000003 /
--      20260416000004 both call PERFORM increment_saldo(user_id, amount)
--      with neither reason nor key. Every cancel that runs writes an
--      audit row with reason='adjustment' and NULL key. If the flow
--      re-fires (retry, double-tap, test runner), saldo is double-credited.
--
--   2. stripe-webhook/index.ts — two saldo-credit paths.
--
--   3. user_detail_panel.dart (admin saldo edit).
--
-- This migration replaces cancel_booking to pass both a deterministic
-- idempotency key ('cancel:{booking_id}') and an explicit reason. The
-- stripe webhook and admin panel are patched in the same commit but land
-- as code edits (TS + Dart), not SQL.
--
-- Detection that triggered this: BC's superadmin saldo grew from an
-- intentional +5000 MXN to 8633 MXN over two days of test bookings. 119
-- saldo_ledger rows for that user, all reason='adjustment', all with
-- NULL idempotency_key. See saldo_ledger audit 2026-04-20.
-- =============================================================================

-- Re-declare cancel_booking with the idempotency-aware increment_saldo call.
-- Body mirrors 20260416000004_cancel_booking_debt_and_tax.sql with ONLY the
-- refund increment line changed. If that migration is rewritten, this patch
-- needs to be re-applied.

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
  v_service_id     uuid;
  v_tax_reversal_result jsonb;
BEGIN
  -- 1. Row lock the booking
  SELECT * INTO v_booking
  FROM appointments
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking no encontrado: %', p_booking_id;
  END IF;

  -- 2. Idempotency: already cancelled?
  IF v_booking.status IN ('cancelled_customer', 'cancelled_business') THEN
    RETURN jsonb_build_object(
      'already_cancelled', true,
      'refund_amount', 0,
      'status', v_booking.status,
      'commission_kept', 0,
      'seller_debt_created', 0
    );
  END IF;

  -- 3. Determine cancel status + commission rate
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

  -- 4. Hours until appointment
  v_hours_until := EXTRACT(EPOCH FROM (v_booking.starts_at - now())) / 3600;

  -- 5. Deposit amount (from service config)
  SELECT COALESCE(s.deposit_amount, 0) INTO v_deposit_amount
  FROM services s
  WHERE s.id = v_booking.service_id;

  -- 6. BC commission (based on booking_source)
  IF COALESCE(v_booking.booking_source, 'bc_marketplace') = 'bc_marketplace' THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;
  v_bc_commission := ROUND(v_booking.price * v_commission_rate, 2);

  -- 7. Refund calculation
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

  -- 7a. Credit buyer saldo (IDEMPOTENT — this is the fix)
  IF v_refund_amount > 0 THEN
    PERFORM increment_saldo(
      v_booking.user_id,
      v_refund_amount,
      'cancellation_refund',
      'cancel:' || p_booking_id::text
    );
  END IF;

  -- 7b. Seller debt + tax reversal (carry-over from 20260416000004)
  IF v_refund_amount > 0 AND v_booking.business_id IS NOT NULL THEN
    INSERT INTO salon_debts (
      business_id, appointment_id, amount, reason, status, created_at
    ) VALUES (
      v_booking.business_id,
      v_booking.id,
      v_refund_amount,
      'refund_cancelled_booking',
      'outstanding',
      now()
    )
    ON CONFLICT DO NOTHING;

    -- Reverse tax withholdings recorded for this appointment
    v_tax_reversal_result := reverse_tax_withholding(
      p_appointment_id := v_booking.id,
      p_reason := 'cancellation'
    );
  END IF;

  -- 8. Commission record (if any)
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

  -- 9. Update the appointment
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
    'seller_debt_created', CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE 0 END,
    'tax_reversal', v_tax_reversal_result
  );
END;
$$;

COMMENT ON FUNCTION cancel_booking(uuid, text) IS
  'Cancel an appointment and process the refund idempotently. '
  'Refund uses idempotency key ''cancel:{booking_id}'' so retries never '
  'double-credit buyer saldo.';
