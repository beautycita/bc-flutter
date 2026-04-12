-- =============================================================================
-- Integration test: calculate_payout_with_debt (5-arg version)
-- Runs inside a transaction that rolls back — zero prod impact.
-- =============================================================================

BEGIN;

-- Setup (skip auth.users to avoid trigger conflicts)
INSERT INTO public.profiles (id, username, role)
VALUES ('00000000-0000-0000-0000-000000000002', 'test_integ_owner', 'customer')
ON CONFLICT (id) DO UPDATE SET username = 'test_integ_owner';

INSERT INTO public.businesses (id, owner_id, name, is_active, is_verified)
VALUES ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000002',
        'Test Salon', true, true)
ON CONFLICT (id) DO NOTHING;

-- =========================================================================
-- TEST 1: No debt → full payout
-- =========================================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Ensure no debts for this business
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';

  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    1000.00,  -- gross
    30.00,    -- commission (3%)
    11.03,    -- iva withheld
    25.00     -- isr withheld
  );

  -- Net = 1000 - 30 - 11.03 - 25 = 933.97
  ASSERT r.salon_payout = 933.97,
    format('TEST 1 FAIL: payout expected 933.97, got %s', r.salon_payout);
  ASSERT r.debt_collected = 0, 'TEST 1 FAIL: debt_collected should be 0';
  ASSERT r.remaining_debt = 0, 'TEST 1 FAIL: remaining_debt should be 0';

  RAISE NOTICE 'TEST 1 PASSED: no debt, full payout = 933.97';
END $$;

-- =========================================================================
-- TEST 2: With debt, FIFO deduction, 50% cap
-- =========================================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';

  -- Create 2 debts: $100 (older) and $200 (newer)
  INSERT INTO salon_debts (business_id, original_amount, remaining_amount, reason, source, created_at)
  VALUES
    ('00000000-0000-0000-0000-0000000000b1', 100, 100, 'test debt 1', 'cancellation_commission', now() - interval '2 days'),
    ('00000000-0000-0000-0000-0000000000b1', 200, 200, 'test debt 2', 'chargeback', now() - interval '1 day');

  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    1000.00,  -- gross
    30.00,    -- commission
    11.03,    -- iva
    25.00     -- isr
  );

  -- Net = 933.97
  -- 50% cap of gross = 500
  -- Total debt = 300
  -- Deduction = min(500, 933.97, 300) = 300 (debt is limiting)
  ASSERT r.debt_collected = 300,
    format('TEST 2 FAIL: debt_collected expected 300, got %s', r.debt_collected);
  ASSERT r.salon_payout = 933.97 - 300,
    format('TEST 2 FAIL: payout expected %s, got %s', 933.97-300, r.salon_payout);
  ASSERT r.remaining_debt = 0,
    format('TEST 2 FAIL: remaining expected 0, got %s', r.remaining_debt);

  RAISE NOTICE 'TEST 2 PASSED: FIFO debt collection, 300 deducted, payout = %', r.salon_payout;
END $$;

-- =========================================================================
-- TEST 3: Debt exceeds 50% cap
-- =========================================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';

  -- Huge debt: $5000
  INSERT INTO salon_debts (business_id, original_amount, remaining_amount, reason, source)
  VALUES ('00000000-0000-0000-0000-0000000000b1', 5000, 5000, 'big debt', 'manual');

  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    1000.00,  -- gross
    30.00,
    11.03,
    25.00
  );

  -- Net = 933.97
  -- 50% cap = 500
  -- Debt = 5000
  -- Deduction = min(500, 933.97, 5000) = 500 (cap is limiting)
  ASSERT r.debt_collected = 500,
    format('TEST 3 FAIL: debt_collected expected 500, got %s', r.debt_collected);
  ASSERT r.salon_payout = 933.97 - 500,
    format('TEST 3 FAIL: payout expected %s, got %s', 933.97-500, r.salon_payout);
  ASSERT r.remaining_debt = 4500,
    format('TEST 3 FAIL: remaining expected 4500, got %s', r.remaining_debt);

  RAISE NOTICE 'TEST 3 PASSED: debt exceeds 50%% cap, deducted 500, remaining 4500';
END $$;

-- =========================================================================
-- TEST 4: Negative net guard (deductions > gross)
-- =========================================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';

  -- Net would be negative: gross=100, comm=50, iva=30, isr=40 → net = -20
  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    100.00,
    50.00,
    30.00,
    40.00
  );

  -- Net clamped to 0
  ASSERT r.salon_payout >= 0,
    format('TEST 4 FAIL: salon_payout should be >= 0, got %s', r.salon_payout);
  ASSERT r.debt_collected = 0,
    'TEST 4 FAIL: no debt to collect with zero net';

  RAISE NOTICE 'TEST 4 PASSED: negative net clamped to 0, payout = %', r.salon_payout;
END $$;

ROLLBACK;
