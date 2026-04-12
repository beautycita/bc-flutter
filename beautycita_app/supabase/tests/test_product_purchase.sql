-- =============================================================================
-- Integration test: purchase_product_with_saldo
-- Runs inside a transaction that rolls back — zero prod impact.
-- =============================================================================

BEGIN;

-- Setup (skip auth.users to avoid trigger conflicts)
INSERT INTO public.profiles (id, username, role, saldo)
VALUES ('00000000-0000-0000-0000-000000000001', 'test_integ_user', 'customer', 2000.00)
ON CONFLICT (id) DO UPDATE SET saldo = 2000.00, username = 'test_integ_user';

INSERT INTO public.profiles (id, username, role)
VALUES ('00000000-0000-0000-0000-000000000002', 'test_integ_owner', 'customer')
ON CONFLICT (id) DO UPDATE SET username = 'test_integ_owner';

INSERT INTO public.businesses (id, owner_id, name, is_active, is_verified)
VALUES ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000002',
        'Test Salon', true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, business_id, name, price, photo_url, category, in_stock)
VALUES ('00000000-0000-0000-0000-00000000pr01', '00000000-0000-0000-0000-0000000000b1',
        'Shampoo Test', 450.00, 'https://example.com/shampoo.jpg', 'shampoo', true)
ON CONFLICT (id) DO NOTHING;

-- =========================================================================
-- TEST 1: Successful product purchase
-- =========================================================================
DO $$
DECLARE
  r jsonb;
  v_saldo numeric;
  v_cr_count int;
BEGIN
  r := purchase_product_with_saldo(
    p_user_id       := '00000000-0000-0000-0000-000000000001'::uuid,
    p_business_id   := '00000000-0000-0000-0000-0000000000b1'::uuid,
    p_product_id    := '00000000-0000-0000-0000-00000000pr01'::uuid,
    p_product_name  := 'Shampoo Test',
    p_quantity      := 1,
    p_total_amount  := 450.00
  );

  ASSERT (r->>'order_id') IS NOT NULL, 'TEST 1 FAIL: order_id is null';
  ASSERT (r->>'already_existed')::boolean = false, 'TEST 1 FAIL: should not already exist';

  -- Commission: 10% of 450 = 45
  ASSERT (r->>'commission')::numeric = 45.00,
    format('TEST 1 FAIL: commission expected 45, got %s', r->>'commission');

  -- Saldo deducted: 2000 - 450 = 1550
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 1550.00,
    format('TEST 1 FAIL: saldo expected 1550, got %s', v_saldo);

  -- Commission record created
  SELECT count(*) INTO v_cr_count FROM commission_records
  WHERE order_id = (r->>'order_id')::uuid AND source = 'product_sale';
  ASSERT v_cr_count = 1, 'TEST 1 FAIL: commission_record not created';

  RAISE NOTICE 'TEST 1 PASSED: product purchase, saldo deducted, commission recorded';
END $$;

-- =========================================================================
-- TEST 2: Insufficient saldo
-- =========================================================================
DO $$
DECLARE
  r jsonb;
BEGIN
  UPDATE profiles SET saldo = 10.00 WHERE id = '00000000-0000-0000-0000-000000000001';

  BEGIN
    r := purchase_product_with_saldo(
      p_user_id       := '00000000-0000-0000-0000-000000000001'::uuid,
      p_business_id   := '00000000-0000-0000-0000-0000000000b1'::uuid,
      p_product_id    := '00000000-0000-0000-0000-00000000pr01'::uuid,
      p_product_name  := 'Shampoo Too Expensive',
      p_quantity      := 1,
      p_total_amount  := 9999.00
    );
    RAISE EXCEPTION 'TEST 2 FAIL: should have raised insufficient saldo';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%Saldo insuficiente%',
      format('TEST 2 FAIL: expected saldo error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'TEST 2 PASSED: insufficient saldo raises exception';
END $$;

ROLLBACK;
