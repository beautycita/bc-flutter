-- =============================================================================
-- Run all SQL integration tests in a single transaction.
-- Disables the auth trigger, creates test data, runs all tests, then ROLLBACK.
-- Zero prod impact.
-- =============================================================================

BEGIN;

-- Disable the trigger that auto-creates profiles on auth.users INSERT
ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_created;

-- =========================================================================
-- SHARED TEST DATA
-- =========================================================================
INSERT INTO auth.users (id, email, encrypted_password, role, aud, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'test-user@test.local', 'test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'test-owner@test.local', 'test', 'authenticated', 'authenticated', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, username, role, saldo)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'test_integ_user', 'customer', 5000.00),
  ('00000000-0000-0000-0000-000000000002', 'test_integ_owner', 'customer', 0)
ON CONFLICT (id) DO UPDATE SET saldo = EXCLUDED.saldo, username = EXCLUDED.username;

INSERT INTO public.businesses (id, owner_id, name, is_active, is_verified, rfc, cancellation_hours, deposit_required, deposit_percentage)
VALUES
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000002',
   'Test Salon WITH RFC', true, true, 'TESTRFC123456', 24, true, 20),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000002',
   'Test Salon NO RFC', true, true, NULL, 24, false, 0)
ON CONFLICT (id) DO UPDATE SET
  rfc = EXCLUDED.rfc, is_active = true, is_verified = true,
  cancellation_hours = EXCLUDED.cancellation_hours,
  deposit_required = EXCLUDED.deposit_required,
  deposit_percentage = EXCLUDED.deposit_percentage;

INSERT INTO public.products (id, business_id, name, price, photo_url, category, in_stock)
VALUES ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
        'Shampoo Test', 450.00, 'https://example.com/shampoo.jpg', 'shampoo', true)
ON CONFLICT (id) DO NOTHING;

-- =========================================================================
-- TEST SUITE 1: create_booking_with_financials
-- =========================================================================

-- T1.1: Saldo payment, WITH RFC, marketplace
DO $$
DECLARE r jsonb; v_saldo numeric; v_tw int; v_cr int;
BEGIN
  UPDATE profiles SET saldo = 5000 WHERE id = '00000000-0000-0000-0000-000000000001';
  r := create_booking_with_financials(
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    '', 'Manicure', 'manicure',
    now() + interval '2h', now() + interval '3h',
    350.00, 'saldo', 'bc_marketplace');
  ASSERT (r->>'booking_id') IS NOT NULL, 'T1.1: booking_id null';
  ASSERT (r->>'tax_base')::numeric = ROUND(350.00/1.16, 2), format('T1.1: tax_base %s', r->>'tax_base');
  ASSERT (r->>'isr_withheld')::numeric = ROUND(350*0.025, 2), format('T1.1: isr %s', r->>'isr_withheld');
  ASSERT (r->>'commission')::numeric = ROUND(350*0.03, 2), format('T1.1: comm %s', r->>'commission');
  ASSERT (r->>'provider_net')::numeric >= 0, 'T1.1: net negative';
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 4650, format('T1.1: saldo %s', v_saldo);
  SELECT count(*) INTO v_tw FROM tax_withholdings WHERE appointment_id = (r->>'booking_id')::uuid;
  ASSERT v_tw = 1, 'T1.1: no tax_withholdings row';
  SELECT count(*) INTO v_cr FROM commission_records WHERE appointment_id = (r->>'booking_id')::uuid;
  ASSERT v_cr = 1, 'T1.1: no commission_record';
  RAISE NOTICE 'PASS T1.1: saldo, WITH RFC, marketplace';
END $$;

-- T1.2: Card payment, NO RFC (high rates)
DO $$
DECLARE r jsonb; v_saldo numeric;
BEGIN
  UPDATE profiles SET saldo = 5000 WHERE id = '00000000-0000-0000-0000-000000000001';
  r := create_booking_with_financials(
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-0000000000b2'::uuid,
    '', 'Corte', 'corte',
    now() + interval '4h', now() + interval '5h',
    1000.00, 'card', 'bc_marketplace');
  ASSERT (r->>'isr_withheld')::numeric = 200, format('T1.2: isr %s', r->>'isr_withheld');
  ASSERT (r->>'saldo_deducted')::boolean = false, 'T1.2: saldo should not deduct for card';
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 5000, format('T1.2: saldo changed to %s', v_saldo);
  RAISE NOTICE 'PASS T1.2: card, NO RFC, saldo untouched';
END $$;

-- T1.3: Cash_direct, salon_direct (0% commission)
DO $$
DECLARE r jsonb;
BEGIN
  r := create_booking_with_financials(
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    '', 'Blowout', 'blowout',
    now() + interval '6h', now() + interval '7h',
    500.00, 'cash_direct', 'salon_direct');
  ASSERT (r->>'commission')::numeric = 0, format('T1.3: comm %s', r->>'commission');
  ASSERT (r->>'commission_rate')::numeric = 0, 'T1.3: rate not 0';
  RAISE NOTICE 'PASS T1.3: cash_direct, salon_direct, 0%% commission';
END $$;

-- T1.4: Insufficient saldo
DO $$
DECLARE r jsonb;
BEGIN
  UPDATE profiles SET saldo = 10 WHERE id = '00000000-0000-0000-0000-000000000001';
  BEGIN
    r := create_booking_with_financials(
      '00000000-0000-0000-0000-000000000001'::uuid,
      '00000000-0000-0000-0000-0000000000b1'::uuid,
      '', 'Expensive', 'test',
      now() + interval '8h', now() + interval '9h',
      9999.00, 'saldo', 'bc_marketplace');
    RAISE EXCEPTION 'T1.4: should have raised';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%Saldo insuficiente%', format('T1.4: wrong error: %s', SQLERRM);
  END;
  RAISE NOTICE 'PASS T1.4: insufficient saldo raises exception';
END $$;

-- T1.5: Invalid payment method
DO $$
DECLARE r jsonb;
BEGIN
  BEGIN
    r := create_booking_with_financials(
      '00000000-0000-0000-0000-000000000001'::uuid,
      '00000000-0000-0000-0000-0000000000b1'::uuid,
      '', 'Invalid', 'test',
      now() + interval '10h', now() + interval '11h',
      100.00, 'bitcoin', 'bc_marketplace');
    RAISE EXCEPTION 'T1.5: should have raised';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%no soportado%', format('T1.5: wrong error: %s', SQLERRM);
  END;
  RAISE NOTICE 'PASS T1.5: invalid method raises exception';
END $$;

-- =========================================================================
-- TEST SUITE 2: cancel_booking
-- =========================================================================

-- T2.1: Already cancelled → no-op
DO $$
DECLARE r jsonb; v_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO appointments (id, user_id, business_id, service_name, starts_at, ends_at, price, status, payment_status, booking_source)
  VALUES (v_id, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1',
          'Already Cancelled', now()+interval '48h', now()+interval '49h', 500, 'cancelled_customer', 'paid', 'bc_marketplace');
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
  r := cancel_booking(v_id, 'customer');
  ASSERT (r->>'already_cancelled')::boolean = true, 'T2.1: not already_cancelled';
  ASSERT (r->>'refund_amount')::numeric = 0, 'T2.1: refund not 0';
  RAISE NOTICE 'PASS T2.1: already cancelled → no-op';
END $$;

-- T2.2: Free cancel, marketplace, paid → refund minus 3%
DO $$
DECLARE r jsonb; v_id uuid := gen_random_uuid(); v_saldo numeric;
BEGIN
  UPDATE profiles SET saldo = 0 WHERE id = '00000000-0000-0000-0000-000000000001';
  INSERT INTO appointments (id, user_id, business_id, service_name, starts_at, ends_at, price, status, payment_status, booking_source)
  VALUES (v_id, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1',
          'Free Cancel', now()+interval '48h', now()+interval '49h', 1000, 'confirmed', 'paid', 'bc_marketplace');
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
  r := cancel_booking(v_id, 'customer');
  ASSERT (r->>'is_free_cancel')::boolean = true, 'T2.2: not free cancel';
  ASSERT (r->>'refund_amount')::numeric = 970, format('T2.2: refund %s', r->>'refund_amount');
  ASSERT (r->>'commission_kept')::numeric = 30, format('T2.2: comm %s', r->>'commission_kept');
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 970, format('T2.2: saldo %s', v_saldo);
  RAISE NOTICE 'PASS T2.2: free cancel, refund=970, commission=30, saldo credited';
END $$;

-- T2.3: Unpaid cancel → no money moves
DO $$
DECLARE r jsonb; v_id uuid := gen_random_uuid();
BEGIN
  UPDATE profiles SET saldo = 0 WHERE id = '00000000-0000-0000-0000-000000000001';
  INSERT INTO appointments (id, user_id, business_id, service_name, starts_at, ends_at, price, status, payment_status, booking_source)
  VALUES (v_id, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1',
          'Unpaid', now()+interval '48h', now()+interval '49h', 500, 'pending', 'pending', 'bc_marketplace');
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
  r := cancel_booking(v_id, 'customer');
  ASSERT (r->>'refund_amount')::numeric = 0, 'T2.3: refund not 0';
  ASSERT (r->>'commission_kept')::numeric = 0, 'T2.3: comm not 0';
  RAISE NOTICE 'PASS T2.3: unpaid cancel, no money moves';
END $$;

-- =========================================================================
-- TEST SUITE 3: purchase_product_with_saldo
-- =========================================================================

-- T3.1: Successful purchase
DO $$
DECLARE r jsonb; v_saldo numeric; v_cr int;
BEGIN
  UPDATE profiles SET saldo = 2000 WHERE id = '00000000-0000-0000-0000-000000000001';
  r := purchase_product_with_saldo(
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    '00000000-0000-0000-0000-0000000000a1'::uuid,
    'Shampoo Test', 1, 450.00);
  ASSERT (r->>'order_id') IS NOT NULL, 'T3.1: order_id null';
  ASSERT (r->>'commission')::numeric = 45, format('T3.1: comm %s', r->>'commission');
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 1550, format('T3.1: saldo %s', v_saldo);
  SELECT count(*) INTO v_cr FROM commission_records WHERE order_id = (r->>'order_id')::uuid;
  ASSERT v_cr = 1, 'T3.1: no commission_record';
  RAISE NOTICE 'PASS T3.1: product purchase, saldo=1550, commission=45';
END $$;

-- T3.2: Insufficient saldo
DO $$
DECLARE r jsonb;
BEGIN
  UPDATE profiles SET saldo = 10 WHERE id = '00000000-0000-0000-0000-000000000001';
  BEGIN
    r := purchase_product_with_saldo(
      '00000000-0000-0000-0000-000000000001'::uuid,
      '00000000-0000-0000-0000-0000000000b1'::uuid,
      '00000000-0000-0000-0000-0000000000a1'::uuid,
      'Too Expensive', 1, 9999.00);
    RAISE EXCEPTION 'T3.2: should have raised';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%Saldo insuficiente%', format('T3.2: wrong error: %s', SQLERRM);
  END;
  RAISE NOTICE 'PASS T3.2: insufficient saldo raises exception';
END $$;

-- =========================================================================
-- TEST SUITE 4: calculate_payout_with_debt
-- =========================================================================

-- T4.1: No debt → full payout
DO $$
DECLARE r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';
  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid, 1000, 30, 11.03, 25);
  ASSERT r.salon_payout = 933.97, format('T4.1: payout %s', r.salon_payout);
  ASSERT r.debt_collected = 0, 'T4.1: debt not 0';
  RAISE NOTICE 'PASS T4.1: no debt, full payout=933.97';
END $$;

-- T4.2: FIFO debt deduction
DO $$
DECLARE r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';
  INSERT INTO salon_debts (business_id, original_amount, remaining_amount, reason, source, created_at) VALUES
    ('00000000-0000-0000-0000-0000000000b1', 100, 100, 'debt1', 'cancellation_commission', now()-interval '2d'),
    ('00000000-0000-0000-0000-0000000000b1', 200, 200, 'debt2', 'chargeback', now()-interval '1d');
  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid, 1000, 30, 11.03, 25);
  ASSERT r.debt_collected = 300, format('T4.2: collected %s', r.debt_collected);
  ASSERT r.salon_payout = 633.97, format('T4.2: payout %s', r.salon_payout);
  ASSERT r.remaining_debt = 0, format('T4.2: remaining %s', r.remaining_debt);
  RAISE NOTICE 'PASS T4.2: FIFO, 300 collected, payout=633.97';
END $$;

-- T4.3: 50% cap limits deduction
DO $$
DECLARE r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';
  INSERT INTO salon_debts (business_id, original_amount, remaining_amount, reason, source)
  VALUES ('00000000-0000-0000-0000-0000000000b1', 5000, 5000, 'huge', 'manual');
  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid, 1000, 30, 11.03, 25);
  ASSERT r.debt_collected = 500, format('T4.3: collected %s', r.debt_collected);
  ASSERT r.remaining_debt = 4500, format('T4.3: remaining %s', r.remaining_debt);
  RAISE NOTICE 'PASS T4.3: 50%% cap, collected=500, remaining=4500';
END $$;

-- T4.4: Negative net guard
DO $$
DECLARE r RECORD;
BEGIN
  DELETE FROM salon_debts WHERE business_id = '00000000-0000-0000-0000-0000000000b1';
  SELECT * INTO r FROM calculate_payout_with_debt(
    '00000000-0000-0000-0000-0000000000b1'::uuid, 100, 50, 30, 40);
  ASSERT r.salon_payout >= 0, format('T4.4: negative payout %s', r.salon_payout);
  RAISE NOTICE 'PASS T4.4: negative net clamped to 0';
END $$;

-- =========================================================================
-- ROLLBACK — zero prod impact
-- =========================================================================
ROLLBACK;
