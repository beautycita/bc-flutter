-- =============================================================================
-- purchase_product_with_saldo: Atomic product purchase with saldo.
-- Fixes race condition where client reads saldo then does UPDATE with local math.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.purchase_product_with_saldo(
  p_user_id          uuid,
  p_business_id      uuid,
  p_product_id       uuid,
  p_product_name     text,
  p_quantity          int,
  p_total_amount     numeric,
  p_shipping_address jsonb    DEFAULT NULL,
  p_idempotency_key  text     DEFAULT NULL
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
BEGIN
  -- =========================================================================
  -- 0. Idempotency: check for duplicate order
  -- =========================================================================
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing
    FROM public.orders
    WHERE buyer_id = p_user_id
      AND product_id = p_product_id
      AND status != 'cancelled'
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

  -- =========================================================================
  -- 1. Read commission rate
  -- =========================================================================
  v_commission_rate := get_config_rate('commission_rate_product', 0.10);
  v_commission := ROUND(p_total_amount * v_commission_rate, 2);

  -- =========================================================================
  -- 2. Lock user profile and check saldo
  -- =========================================================================
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

  -- =========================================================================
  -- 3. Deduct saldo atomically
  -- =========================================================================
  UPDATE public.profiles
  SET saldo = saldo - p_total_amount, updated_at = now()
  WHERE id = p_user_id;

  -- =========================================================================
  -- 4. Create order
  -- =========================================================================
  INSERT INTO public.orders (
    buyer_id, business_id, product_id, product_name,
    quantity, total_amount, commission_amount,
    status, payment_method, shipping_address
  ) VALUES (
    p_user_id, p_business_id, p_product_id, p_product_name,
    p_quantity, p_total_amount, v_commission,
    'paid', 'saldo', p_shipping_address
  )
  RETURNING id INTO v_order_id;

  -- =========================================================================
  -- 5. Record commission
  -- =========================================================================
  INSERT INTO public.commission_records (
    business_id, order_id, amount, rate, source,
    period_month, period_year, status
  ) VALUES (
    p_business_id, v_order_id, v_commission, v_commission_rate, 'product_sale',
    EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
  );

  -- =========================================================================
  -- 6. Return result
  -- =========================================================================
  RETURN jsonb_build_object(
    'order_id', v_order_id::text,
    'commission', v_commission,
    'already_existed', false
  );
END;
$$;

COMMENT ON FUNCTION public.purchase_product_with_saldo IS
  'Atomic product purchase: locks saldo, deducts, creates order, records commission. '
  'Fixes race condition in product_checkout_sheet.dart.';
