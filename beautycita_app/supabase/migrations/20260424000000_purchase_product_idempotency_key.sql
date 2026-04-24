-- =============================================================================
-- purchase_product_with_saldo: real idempotency + saldo enforcement
-- =============================================================================
-- Bug caught by checkup test "Purchase: insufficient saldo" (2026-04-24):
-- the previous RPC accepted p_idempotency_key but never used it. The lookup
-- matched on (buyer_id, product_id, status<>'cancelled', last 5 min), which
-- meant a SECOND buy of the same product within 5 minutes at ANY price
-- silently returned the first order without checking saldo. A user could
-- "buy" a $999,999 product and the RPC would report success pointing at
-- their earlier $250 order — no saldo check, no new order, no commission.
--
-- Fix:
--   1. Add orders.idempotency_key + partial-unique index.
--   2. Rewrite the RPC's idempotency path to match on idempotency_key
--      (the field that's supposed to guard retries), not on product_id.
--   3. Fall back to the legacy (buyer, product, 5-min) guard ONLY when
--      no idempotency key is supplied (protects the UI double-click path).
--   4. Store the key on every new order.
-- =============================================================================

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_idempotency_key
  ON public.orders (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

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
BEGIN
  -- Idempotency v2 — honor the supplied key.
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
    -- Legacy double-click guard: same buyer+product created within 5 min
    -- AND that order has no idempotency_key. This protects naive UI retries
    -- (tap-tap from a checkout button) without swallowing a different
    -- purchase attempt carrying a distinct key.
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

  INSERT INTO public.commission_records (
    business_id, order_id, amount, rate, source,
    period_month, period_year, status
  ) VALUES (
    p_business_id, v_order_id, v_commission, v_commission_rate, 'product_sale',
    EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
  );

  RETURN jsonb_build_object(
    'order_id', v_order_id::text,
    'commission', v_commission,
    'commission_rate', v_commission_rate,
    'already_existed', false
  );
END;
$$;

COMMENT ON FUNCTION public.purchase_product_with_saldo IS
  'Saldo-paid product purchase with real idempotency. p_idempotency_key is '
  'the only deduplication source when supplied; the legacy 5-minute guard '
  'only fires for calls without a key (UI double-click protection).';
