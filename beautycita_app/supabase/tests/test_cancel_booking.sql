-- =============================================================================
-- Integration test: cancel_booking
-- Runs inside a transaction that rolls back — zero prod impact.
-- NOTE: cancel_booking uses auth.uid() for ownership checks. In direct psql,
--       auth.uid() returns NULL. We test via service_role which bypasses RLS.
--       The is_admin() check allows service_role to cancel as 'business'.
--       For 'customer' cancel, we set the role context.
-- =============================================================================

BEGIN;

-- Setup test data (skip auth.users to avoid trigger conflicts)
INSERT INTO public.profiles (id, username, role, saldo)
VALUES ('00000000-0000-0000-0000-000000000001', 'test_integ_user', 'customer', 0)
ON CONFLICT (id) DO UPDATE SET saldo = 0, username = 'test_integ_user';

INSERT INTO public.businesses (id, owner_id, name, is_active, is_verified, cancellation_hours, deposit_required, deposit_percentage)
VALUES ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000002',
        'Test Salon', true, true, 24, true, 20)
ON CONFLICT (id) DO UPDATE SET cancellation_hours = 24, deposit_required = true, deposit_percentage = 20;

-- =========================================================================
-- TEST 1: Cancel already-cancelled booking → no-op
-- =========================================================================
DO $$
DECLARE
  r jsonb;
  v_booking_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO appointments (id, user_id, business_id, service_name, starts_at, ends_at, price, status, payment_status, booking_source)
  VALUES (v_booking_id, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1',
          'Already Cancelled', now() + interval '48 hours', now() + interval '49 hours',
          500.00, 'cancelled_customer', 'paid', 'bc_marketplace');

  -- Set auth context to the test user
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

  r := cancel_booking(v_booking_id, 'customer');

  ASSERT (r->>'already_cancelled')::boolean = true,
    format('TEST 1 FAIL: expected already_cancelled=true, got %s', r->>'already_cancelled');
  ASSERT (r->>'refund_amount')::numeric = 0,
    'TEST 1 FAIL: refund should be 0 for already cancelled';

  RAISE NOTICE 'TEST 1 PASSED: cancel already-cancelled → no-op';
END $$;

-- =========================================================================
-- TEST 2: Free cancel (within window) — marketplace, paid booking
-- =========================================================================
DO $$
DECLARE
  r jsonb;
  v_booking_id uuid := gen_random_uuid();
  v_saldo numeric;
BEGIN
  -- Reset saldo to 0
  UPDATE profiles SET saldo = 0 WHERE id = '00000000-0000-0000-0000-000000000001';

  -- Booking 48hrs from now (business has 24hr window → this is within free cancel)
  INSERT INTO appointments (id, user_id, business_id, service_name, starts_at, ends_at, price, status, payment_status, booking_source)
  VALUES (v_booking_id, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1',
          'Free Cancel Test', now() + interval '48 hours', now() + interval '49 hours',
          1000.00, 'confirmed', 'paid', 'bc_marketplace');

  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

  r := cancel_booking(v_booking_id, 'customer');

  -- Free cancel: refund = price - 3% commission
  ASSERT (r->>'is_free_cancel')::boolean = true,
    'TEST 2 FAIL: should be free cancel';
  ASSERT (r->>'refund_amount')::numeric = 970.00,
    format('TEST 2 FAIL: refund expected 970, got %s', r->>'refund_amount');
  ASSERT (r->>'commission_kept')::numeric = 30.00,
    format('TEST 2 FAIL: commission expected 30, got %s', r->>'commission_kept');
  ASSERT (r->>'deposit_forfeited')::numeric = 0,
    'TEST 2 FAIL: no deposit forfeited on free cancel';

  -- Saldo credited
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 970.00,
    format('TEST 2 FAIL: saldo expected 970, got %s', v_saldo);

  RAISE NOTICE 'TEST 2 PASSED: free cancel, marketplace, refund=970, commission=30';
END $$;

-- =========================================================================
-- TEST 3: Unpaid booking cancel — no money moves
-- =========================================================================
DO $$
DECLARE
  r jsonb;
  v_booking_id uuid := gen_random_uuid();
BEGIN
  UPDATE profiles SET saldo = 0 WHERE id = '00000000-0000-0000-0000-000000000001';

  INSERT INTO appointments (id, user_id, business_id, service_name, starts_at, ends_at, price, status, payment_status, booking_source)
  VALUES (v_booking_id, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1',
          'Unpaid Cancel', now() + interval '48 hours', now() + interval '49 hours',
          500.00, 'pending', 'pending', 'bc_marketplace');

  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

  r := cancel_booking(v_booking_id, 'customer');

  ASSERT (r->>'refund_amount')::numeric = 0, 'TEST 3 FAIL: unpaid cancel should refund 0';
  ASSERT (r->>'commission_kept')::numeric = 0, 'TEST 3 FAIL: unpaid cancel should keep 0 commission';

  RAISE NOTICE 'TEST 3 PASSED: unpaid booking cancel, no money moves';
END $$;

ROLLBACK;
