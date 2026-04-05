-- =============================================================================
-- Atomic booking + saldo deduction in a single transaction.
-- Prevents race condition where booking is created but saldo deduction fails.
-- =============================================================================

CREATE OR REPLACE FUNCTION book_with_saldo(
  p_user_id uuid,
  p_business_id uuid,
  p_service_id text,
  p_service_name text,
  p_service_type text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_price numeric,
  p_payment_method text DEFAULT 'saldo',
  p_transport_mode text DEFAULT NULL,
  p_staff_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_booking_source text DEFAULT 'bc_marketplace'
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_saldo numeric;
  v_booking_id uuid;
BEGIN
  -- 1. Check and lock the user's saldo (SELECT FOR UPDATE prevents concurrent reads)
  SELECT saldo INTO v_saldo
  FROM profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_saldo IS NULL THEN
    RAISE EXCEPTION 'Usuario no encontrado';
  END IF;

  IF v_saldo < p_price THEN
    RAISE EXCEPTION 'Saldo insuficiente (% < %)', v_saldo, p_price;
  END IF;

  -- 2. Deduct saldo FIRST (locked row, no race)
  UPDATE profiles
  SET saldo = saldo - p_price,
      updated_at = now()
  WHERE id = p_user_id;

  -- 3. Create the booking
  INSERT INTO appointments (
    user_id, business_id, service_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method,
    transport_mode, staff_id, notes, paid_at, booking_source
  ) VALUES (
    p_user_id, p_business_id, p_service_id, p_service_name, p_service_type,
    p_starts_at, p_ends_at, p_price, 'confirmed', 'paid', p_payment_method,
    p_transport_mode, p_staff_id, p_notes, now(), p_booking_source
  )
  RETURNING id INTO v_booking_id;

  RETURN v_booking_id;
END;
$$;
