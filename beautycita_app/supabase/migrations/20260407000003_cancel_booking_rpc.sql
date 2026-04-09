-- =============================================================================
-- cancel_booking: Atomic server-side cancellation with ownership validation,
-- refund calculation, saldo credit, and commission recording.
--
-- Replaces client-side logic in booking_repository.dart cancelBooking().
-- =============================================================================

CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id   uuid,
  p_cancelled_by text DEFAULT 'customer'  -- 'customer' or 'business'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking        record;
  v_biz            record;
  v_hours_until    int;
  v_is_free_cancel boolean;
  v_bc_commission  numeric;
  v_commission_rate numeric;
  v_refund_amount  numeric;
  v_deposit_forfeited numeric := 0;
  v_deposit_amount numeric;
  v_payment_status text;
  v_cancel_status  text;
BEGIN
  -- =========================================================================
  -- 1. Lock and fetch the booking
  -- =========================================================================
  SELECT a.id, a.user_id, a.business_id, a.price, a.payment_status,
         a.payment_method, a.starts_at, a.status, a.booking_source
  INTO v_booking
  FROM public.appointments a
  WHERE a.id = p_booking_id
  FOR UPDATE;

  IF v_booking IS NULL THEN
    RAISE EXCEPTION 'Cita no encontrada: %', p_booking_id;
  END IF;

  -- Already cancelled? No-op
  IF v_booking.status IN ('cancelled_customer', 'cancelled_business') THEN
    RETURN jsonb_build_object(
      'refund_amount', 0,
      'deposit_forfeited', 0,
      'commission_kept', 0,
      'is_free_cancel', true,
      'already_cancelled', true
    );
  END IF;

  -- =========================================================================
  -- 2. Ownership validation
  -- =========================================================================
  IF p_cancelled_by = 'customer' THEN
    IF v_booking.user_id != auth.uid() THEN
      RAISE EXCEPTION 'No autorizado para cancelar esta cita';
    END IF;
    v_cancel_status := 'cancelled_customer';
  ELSIF p_cancelled_by = 'business' THEN
    -- Verify caller owns the business
    IF NOT EXISTS (
      SELECT 1 FROM public.businesses
      WHERE id = v_booking.business_id AND owner_id = auth.uid()
    ) AND NOT is_admin() THEN
      RAISE EXCEPTION 'No autorizado para cancelar esta cita';
    END IF;
    v_cancel_status := 'cancelled_business';
  ELSE
    RAISE EXCEPTION 'cancelled_by invalido: %', p_cancelled_by;
  END IF;

  -- =========================================================================
  -- 3. Fetch business cancellation policy
  -- =========================================================================
  SELECT cancellation_hours, deposit_percentage, deposit_required
  INTO v_biz
  FROM public.businesses
  WHERE id = v_booking.business_id;

  -- =========================================================================
  -- 4. Calculate refund
  -- =========================================================================
  v_hours_until := EXTRACT(EPOCH FROM (v_booking.starts_at - now())) / 3600;
  v_is_free_cancel := v_hours_until >= COALESCE(v_biz.cancellation_hours, 24);

  -- Commission rate from config based on booking source
  IF v_booking.booking_source IN ('bc_marketplace', 'invite_link') THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;
  v_bc_commission := ROUND(v_booking.price * v_commission_rate, 2);

  IF v_booking.payment_status != 'paid' OR v_booking.price <= 0 THEN
    -- Not paid: just cancel, no money to move
    v_refund_amount := 0;
    v_bc_commission := 0;

  ELSIF p_cancelled_by = 'business' THEN
    -- Salon cancelled: full refund to customer, commission still charged to salon
    v_refund_amount := v_booking.price;

  ELSIF v_is_free_cancel THEN
    -- Within free cancellation window: full refund minus BC commission
    v_refund_amount := v_booking.price - v_bc_commission;

  ELSIF COALESCE(v_biz.deposit_required, false) AND COALESCE(v_biz.deposit_percentage, 0) > 0 THEN
    -- Late cancel with deposit policy: deposit forfeited
    v_deposit_amount := ROUND(v_booking.price * (v_biz.deposit_percentage / 100.0), 2);
    v_deposit_forfeited := v_deposit_amount;
    v_refund_amount := GREATEST(v_booking.price - v_deposit_amount - v_bc_commission, 0);

  ELSE
    -- Late cancel, no deposit: full refund minus BC commission
    v_refund_amount := v_booking.price - v_bc_commission;
  END IF;

  -- =========================================================================
  -- 5. Determine payment status
  -- =========================================================================
  IF v_booking.payment_status = 'paid' THEN
    IF v_refund_amount > 0 THEN
      v_payment_status := 'refunded_to_saldo';
    ELSIF v_deposit_forfeited > 0 THEN
      v_payment_status := 'deposit_forfeited';
    ELSE
      v_payment_status := v_booking.payment_status;
    END IF;
  ELSE
    v_payment_status := v_booking.payment_status;
  END IF;

  -- =========================================================================
  -- 6. Update appointment
  -- =========================================================================
  UPDATE public.appointments
  SET status = v_cancel_status,
      payment_status = v_payment_status,
      refund_amount = v_refund_amount,
      refunded_at = CASE WHEN v_refund_amount > 0 THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_booking_id;

  -- =========================================================================
  -- 7. Credit saldo (refund)
  -- =========================================================================
  IF v_refund_amount > 0 THEN
    PERFORM increment_saldo(v_booking.user_id, v_refund_amount);
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

COMMENT ON FUNCTION public.cancel_booking IS
  'Atomic booking cancellation with ownership validation, refund calculation, '
  'saldo credit, and commission recording. Replaces client-side cancelBooking().';
