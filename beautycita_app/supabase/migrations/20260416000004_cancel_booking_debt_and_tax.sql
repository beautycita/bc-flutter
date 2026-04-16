-- Add seller debt creation + tax reversal to cancel_booking RPC
-- Policy: all refunds → saldo credit + seller debt + tax reversal

CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id   uuid,
  p_cancelled_by text DEFAULT 'customer'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking        RECORD;
  v_biz            RECORD;
  v_commission_rate numeric := 0;
  v_bc_commission   numeric := 0;
  v_refund_amount   numeric := 0;
  v_deposit_amount  numeric := 0;
  v_deposit_forfeited numeric := 0;
  v_cancel_status   text;
  v_payment_status  text;
  v_is_free_cancel  boolean := false;
  v_cancel_window   interval;
BEGIN
  -- =========================================================================
  -- 1. Lock the booking row for update
  -- =========================================================================
  SELECT * INTO v_booking
  FROM public.appointments
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Booking not found');
  END IF;

  -- Already cancelled → return early
  IF v_booking.status IN ('cancelled_customer', 'cancelled_business') THEN
    RETURN jsonb_build_object('already_cancelled', true);
  END IF;

  -- =========================================================================
  -- 2. Get business data
  -- =========================================================================
  SELECT * INTO v_biz
  FROM public.businesses
  WHERE id = v_booking.business_id;

  -- =========================================================================
  -- 3. Determine cancel status
  -- =========================================================================
  v_cancel_status := CASE
    WHEN p_cancelled_by = 'business' THEN 'cancelled_business'
    ELSE 'cancelled_customer'
  END;

  -- =========================================================================
  -- 4. Commission rate by booking source
  -- =========================================================================
  IF v_booking.booking_source IN ('bc_marketplace', 'invite_link') THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;

  v_bc_commission := ROUND(v_booking.price * v_commission_rate, 2);

  -- =========================================================================
  -- 5. Calculate refund amount
  -- =========================================================================
  v_cancel_window := COALESCE(v_biz.cancellation_hours, 24) * interval '1 hour';
  v_is_free_cancel := v_booking.starts_at - now() > v_cancel_window;

  IF v_booking.payment_status != 'paid' OR v_booking.price <= 0 THEN
    v_refund_amount := 0;
  ELSIF p_cancelled_by = 'business' THEN
    -- Salon cancelled: full refund, commission still charged
    v_refund_amount := v_booking.price;
  ELSIF v_is_free_cancel THEN
    -- Free cancellation window: full minus commission
    v_refund_amount := v_booking.price - v_bc_commission;
  ELSIF COALESCE(v_biz.deposit_required, false) AND COALESCE(v_biz.deposit_percentage, 0) > 0 THEN
    -- Late cancel with deposit: deposit forfeited
    v_deposit_amount := ROUND(v_booking.price * (v_biz.deposit_percentage / 100.0), 2);
    v_deposit_forfeited := v_deposit_amount;
    v_refund_amount := GREATEST(v_booking.price - v_deposit_amount - v_bc_commission, 0);
  ELSE
    -- Late cancel, no deposit
    v_refund_amount := v_booking.price - v_bc_commission;
  END IF;

  -- =========================================================================
  -- 6. Payment status
  -- =========================================================================
  IF v_booking.payment_status = 'paid' AND v_refund_amount > 0 THEN
    v_payment_status := 'refunded_to_saldo';
  ELSIF v_booking.payment_status = 'paid' THEN
    v_payment_status := 'paid';
  ELSE
    v_payment_status := v_booking.payment_status;
  END IF;

  -- =========================================================================
  -- 6b. Update the booking
  -- =========================================================================
  UPDATE public.appointments
  SET status = v_cancel_status,
      payment_status = v_payment_status,
      refund_amount = v_refund_amount,
      refunded_at = CASE WHEN v_refund_amount > 0 THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_booking_id;

  -- =========================================================================
  -- 7. Credit buyer saldo (refund)
  -- =========================================================================
  IF v_refund_amount > 0 THEN
    PERFORM increment_saldo(v_booking.user_id, v_refund_amount);
  END IF;

  -- =========================================================================
  -- 7b. Create seller debt (seller owes back the refunded amount)
  -- =========================================================================
  IF v_refund_amount > 0 THEN
    INSERT INTO public.salon_debts (
      business_id, original_amount, remaining_amount,
      reason, source, appointment_id
    ) VALUES (
      v_booking.business_id, v_refund_amount, v_refund_amount,
      'booking_cancellation_' || p_cancelled_by,
      'booking_refund',
      p_booking_id
    );
  END IF;

  -- =========================================================================
  -- 7c. Reverse tax withholdings (LISR Art. 113-A compliance)
  -- =========================================================================
  IF v_refund_amount > 0 THEN
    PERFORM reverse_tax_withholding(p_booking_id, 'booking_cancellation');
  END IF;

  -- =========================================================================
  -- 8. Record commission (audit trail)
  -- =========================================================================
  IF v_bc_commission > 0 THEN
    INSERT INTO public.commission_records (
      business_id, appointment_id, amount, rate, source,
      period_month, period_year, status
    ) VALUES (
      v_booking.business_id, p_booking_id, v_bc_commission, v_commission_rate,
      CASE WHEN p_cancelled_by = 'business' THEN 'salon_cancellation' ELSE 'cancellation' END,
      EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
    )
    ON CONFLICT (appointment_id, source) DO NOTHING;
  END IF;

  -- =========================================================================
  -- 9. Return result
  -- =========================================================================
  RETURN jsonb_build_object(
    'refund_amount', v_refund_amount,
    'deposit_forfeited', v_deposit_forfeited,
    'commission_kept', v_bc_commission,
    'is_free_cancel', v_is_free_cancel,
    'already_cancelled', false
  );
END;
$$;
