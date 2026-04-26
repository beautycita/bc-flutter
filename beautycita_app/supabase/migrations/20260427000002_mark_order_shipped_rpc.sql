-- =============================================================================
-- mark_order_shipped — atomic ship transition with claim-window opening
-- =============================================================================

CREATE OR REPLACE FUNCTION public.mark_order_shipped(
  p_order_id uuid,
  p_tracking_number text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_window_days int;
  v_claim_ends timestamptz;
  v_tn text;
BEGIN
  v_tn := trim(p_tracking_number);
  IF length(v_tn) < 4 OR length(v_tn) > 60 THEN
    RAISE EXCEPTION 'tracking_number must be 4-60 chars';
  END IF;

  SELECT o.id, o.business_id, o.status, o.tracking_number, o.fulfillment_method,
         b.owner_id
    INTO v_order
    FROM orders o JOIN businesses b ON b.id = o.business_id
    WHERE o.id = p_order_id
    FOR UPDATE OF o;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found: %', p_order_id;
  END IF;

  -- Caller must be the salon owner.
  IF v_order.owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'forbidden — only salon owner can mark shipped';
  END IF;

  IF v_order.fulfillment_method <> 'ship' THEN
    RAISE EXCEPTION 'order is not a ship-fulfillment order';
  END IF;

  -- Idempotency: already shipped with same tracking → no-op success.
  IF v_order.status = 'shipped' AND v_order.tracking_number = v_tn THEN
    RETURN jsonb_build_object('ok', true, 'already_shipped', true,
                               'order_id', p_order_id);
  END IF;

  IF v_order.status <> 'paid' THEN
    RAISE EXCEPTION 'cannot mark shipped from status %', v_order.status;
  END IF;

  v_window_days := COALESCE((SELECT value::int FROM app_config
                              WHERE key = 'pos_ship_claim_window_days'), 14);
  v_claim_ends := now() + (v_window_days || ' days')::interval;

  UPDATE orders
     SET status = 'shipped',
         shipped_at = now(),
         tracking_number = v_tn,
         claim_window_ends_at = v_claim_ends,
         updated_at = now()
   WHERE id = p_order_id AND status = 'paid';

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', p_order_id,
    'shipped_at', now(),
    'tracking_number', v_tn,
    'claim_window_ends_at', v_claim_ends
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_order_shipped(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.mark_order_shipped(uuid, text) IS
  'Salon-owner-callable RPC. Atomic paid→shipped + tracking_number + claim_window_ends_at. Idempotent on (order, tracking).';

-- ── purchase_product_with_saldo: accept fulfillment_method ───────────────────
CREATE OR REPLACE FUNCTION public.purchase_product_with_saldo(
  p_user_id uuid,
  p_business_id uuid,
  p_product_id uuid,
  p_product_name text,
  p_quantity integer,
  p_total_amount numeric,
  p_shipping_address jsonb DEFAULT NULL::jsonb,
  p_idempotency_key text DEFAULT NULL::text,
  p_fulfillment_method text DEFAULT 'ship'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_existing       jsonb;
  v_buyer_saldo    numeric;
  v_commission_rate numeric;
  v_commission     numeric;
  v_order_id       uuid;
  v_biz_is_test    boolean := false;
  v_saldo_idem     text;
  v_status         text;
  v_qr_token       text;
  v_qr_hash        text;
  v_qr_expires     timestamptz;
BEGIN
  IF p_quantity <= 0 THEN RAISE EXCEPTION 'quantity must be positive'; END IF;
  IF p_total_amount <= 0 THEN RAISE EXCEPTION 'total_amount must be positive'; END IF;
  IF p_fulfillment_method NOT IN ('ship', 'pickup') THEN
    RAISE EXCEPTION 'fulfillment_method must be ship or pickup';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT jsonb_build_object(
      'order_id', id::text,
      'commission', commission_amount,
      'total_amount', total_amount,
      'already_existed', true
    ) INTO v_existing
    FROM public.orders
    WHERE idempotency_key = p_idempotency_key;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  SELECT COALESCE(is_test, false) INTO v_biz_is_test
    FROM businesses WHERE id = p_business_id;

  SELECT saldo INTO v_buyer_saldo FROM profiles WHERE id = p_user_id FOR UPDATE;
  IF v_buyer_saldo IS NULL THEN RAISE EXCEPTION 'Buyer not found'; END IF;
  IF v_buyer_saldo < p_total_amount THEN
    RAISE EXCEPTION 'Insufficient saldo: % < %', v_buyer_saldo, p_total_amount;
  END IF;

  v_commission_rate := get_config_rate('commission_rate_product', 0.10);
  v_commission := ROUND(p_total_amount * v_commission_rate, 2);

  v_saldo_idem := COALESCE(p_idempotency_key,
    'order:' || p_user_id::text || ':' || gen_random_uuid()::text) || ':saldo';
  PERFORM increment_saldo(p_user_id, -p_total_amount, 'product_purchase', v_saldo_idem);
  UPDATE profiles SET updated_at = now() WHERE id = p_user_id;

  -- Pickup orders start in awaiting_pickup, not paid. QR token minted inline.
  IF p_fulfillment_method = 'pickup' THEN
    v_status := 'awaiting_pickup';
    v_qr_token := encode(gen_random_bytes(32), 'base64');
    v_qr_hash  := encode(digest(v_qr_token, 'sha256'), 'hex');
    v_qr_expires := now() + interval '7 days';
  ELSE
    v_status := 'paid';
  END IF;

  INSERT INTO orders (
    buyer_id, business_id, product_id, product_name, quantity,
    total_amount, commission_amount, payment_method, status,
    fulfillment_method,
    pickup_qr_token_hash, pickup_qr_expires_at, pickup_qr_issued_at,
    shipping_address, idempotency_key
  ) VALUES (
    p_user_id, p_business_id, p_product_id, p_product_name, p_quantity,
    p_total_amount, v_commission, 'saldo', v_status,
    p_fulfillment_method,
    CASE WHEN p_fulfillment_method = 'pickup' THEN v_qr_hash ELSE NULL END,
    CASE WHEN p_fulfillment_method = 'pickup' THEN v_qr_expires ELSE NULL END,
    CASE WHEN p_fulfillment_method = 'pickup' THEN now() ELSE NULL END,
    CASE WHEN p_fulfillment_method = 'ship' THEN p_shipping_address ELSE NULL END,
    p_idempotency_key
  )
  RETURNING id INTO v_order_id;

  IF v_commission > 0 AND NOT v_biz_is_test THEN
    INSERT INTO commission_records (
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
    'total_amount', p_total_amount,
    'fulfillment_method', p_fulfillment_method,
    'status', v_status,
    -- For pickup, return cleartext token ONCE so the client can render the QR.
    -- Client must persist it; subsequent reads come from generate-pickup-qr.
    'pickup_token', CASE WHEN p_fulfillment_method = 'pickup' THEN v_qr_token ELSE NULL END,
    'pickup_qr_expires_at', v_qr_expires,
    'is_test_business', v_biz_is_test,
    'already_existed', false
  );
END;
$function$;

COMMENT ON FUNCTION public.purchase_product_with_saldo(uuid, uuid, uuid, text, integer, numeric, jsonb, text, text) IS
  'Atomic saldo product purchase. fulfillment_method=ship→paid, =pickup→awaiting_pickup with one-time QR token returned.';
