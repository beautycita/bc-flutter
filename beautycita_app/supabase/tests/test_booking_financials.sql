-- =============================================================================
-- Integration test: create_booking_with_financials
-- Runs inside a transaction that rolls back — zero prod impact.
-- =============================================================================

BEGIN;

-- Setup: create test profiles directly (skip auth.users to avoid handle_new_user trigger conflicts)
-- Running as postgres superuser bypasses RLS.

INSERT INTO public.profiles (id, username, role, saldo)
VALUES ('00000000-0000-0000-0000-000000000001', 'test_integ_user', 'customer', 5000.00)
ON CONFLICT (id) DO UPDATE SET saldo = 5000.00, username = 'test_integ_user';

INSERT INTO public.profiles (id, username, role)
VALUES ('00000000-0000-0000-0000-000000000002', 'test_integ_owner', 'customer')
ON CONFLICT (id) DO UPDATE SET username = 'test_integ_owner';

INSERT INTO public.businesses (id, owner_id, name, is_active, is_verified, rfc)
VALUES ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000002',
        'Test Salon WITH RFC', true, true, 'TESTRFC123456')
ON CONFLICT (id) DO UPDATE SET rfc = 'TESTRFC123456', is_active = true, is_verified = true;

INSERT INTO public.businesses (id, owner_id, name, is_active, is_verified, rfc)
VALUES ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000002',
        'Test Salon NO RFC', true, true, NULL)
ON CONFLICT (id) DO UPDATE SET rfc = NULL, is_active = true, is_verified = true;

-- =========================================================================
-- TEST 1: Saldo payment, WITH RFC, marketplace source
-- =========================================================================
DO $$
DECLARE
  r jsonb;
  v_saldo numeric;
  v_tw_count int;
  v_cr_count int;
BEGIN
  r := create_booking_with_financials(
    p_user_id        := '00000000-0000-0000-0000-000000000001'::uuid,
    p_business_id    := '00000000-0000-0000-0000-0000000000b1'::uuid,
    p_service_id     := 'svc-test-1',
    p_service_name   := 'Manicure Test',
    p_service_type   := 'manicure',
    p_starts_at      := now() + interval '2 hours',
    p_ends_at        := now() + interval '3 hours',
    p_price          := 350.00,
    p_payment_method := 'saldo',
    p_booking_source := 'bc_marketplace'
  );

  -- Booking created
  ASSERT (r->>'booking_id') IS NOT NULL, 'TEST 1 FAIL: booking_id is null';
  ASSERT (r->>'already_existed')::boolean = false, 'TEST 1 FAIL: should not already exist';

  -- Tax math: WITH RFC → ISR 2.5%, IVA 8%
  ASSERT (r->>'tax_base')::numeric = ROUND(350.00 / 1.16, 2),
    format('TEST 1 FAIL: tax_base expected %s got %s', ROUND(350.00/1.16,2), r->>'tax_base');
  ASSERT (r->>'isr_withheld')::numeric = ROUND(350.00 * 0.025, 2),
    format('TEST 1 FAIL: isr expected %s got %s', ROUND(350*0.025,2), r->>'isr_withheld');
  ASSERT (r->>'commission')::numeric = ROUND(350.00 * 0.03, 2),
    format('TEST 1 FAIL: commission expected %s got %s', ROUND(350*0.03,2), r->>'commission');

  -- Saldo deducted
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 5000.00 - 350.00,
    format('TEST 1 FAIL: saldo expected %s got %s', 5000-350, v_saldo);

  -- Tax withholdings ledger row created
  SELECT count(*) INTO v_tw_count FROM tax_withholdings
  WHERE appointment_id = (r->>'booking_id')::uuid;
  ASSERT v_tw_count = 1, 'TEST 1 FAIL: tax_withholdings row not created';

  -- Commission record created (marketplace = 3%)
  SELECT count(*) INTO v_cr_count FROM commission_records
  WHERE appointment_id = (r->>'booking_id')::uuid;
  ASSERT v_cr_count = 1, 'TEST 1 FAIL: commission_record not created';

  -- Provider net is non-negative
  ASSERT (r->>'provider_net')::numeric >= 0, 'TEST 1 FAIL: provider_net is negative';

  RAISE NOTICE 'TEST 1 PASSED: saldo payment, WITH RFC, marketplace';
END $$;

-- =========================================================================
-- TEST 2: Card payment, NO RFC, marketplace source
-- =========================================================================
DO $$
DECLARE
  r jsonb;
  v_saldo numeric;
BEGIN
  -- Reset saldo
  UPDATE profiles SET saldo = 5000.00 WHERE id = '00000000-0000-0000-0000-000000000001';

  r := create_booking_with_financials(
    p_user_id        := '00000000-0000-0000-0000-000000000001'::uuid,
    p_business_id    := '00000000-0000-0000-0000-0000000000b2'::uuid,
    p_service_id     := 'svc-test-2',
    p_service_name   := 'Corte Test',
    p_service_type   := 'corte',
    p_starts_at      := now() + interval '4 hours',
    p_ends_at        := now() + interval '5 hours',
    p_price          := 1000.00,
    p_payment_method := 'card',
    p_booking_source := 'bc_marketplace'
  );

  -- NO RFC → ISR 20%, IVA 16%
  ASSERT (r->>'isr_withheld')::numeric = ROUND(1000.00 * 0.20, 2),
    format('TEST 2 FAIL: isr expected 200 got %s', r->>'isr_withheld');
  ASSERT (r->>'iva_withheld')::numeric = ROUND((1000.00 - ROUND(1000.00/1.16,2)) * 0.16, 2),
    format('TEST 2 FAIL: iva_withheld mismatch: %s', r->>'iva_withheld');

  -- Card: saldo should NOT be deducted
  SELECT saldo INTO v_saldo FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
  ASSERT v_saldo = 5000.00,
    format('TEST 2 FAIL: saldo should not change for card payment, got %s', v_saldo);

  -- saldo_deducted flag
  ASSERT (r->>'saldo_deducted')::boolean = false, 'TEST 2 FAIL: saldo_deducted should be false';

  RAISE NOTICE 'TEST 2 PASSED: card payment, NO RFC, marketplace';
END $$;

-- =========================================================================
-- TEST 3: Cash_direct payment, salon_direct source (0% commission)
-- =========================================================================
DO $$
DECLARE
  r jsonb;
BEGIN
  r := create_booking_with_financials(
    p_user_id        := '00000000-0000-0000-0000-000000000001'::uuid,
    p_business_id    := '00000000-0000-0000-0000-0000000000b1'::uuid,
    p_service_id     := 'svc-test-3',
    p_service_name   := 'Blowout Test',
    p_service_type   := 'blowout',
    p_starts_at      := now() + interval '6 hours',
    p_ends_at        := now() + interval '7 hours',
    p_price          := 500.00,
    p_payment_method := 'cash_direct',
    p_booking_source := 'salon_direct'
  );

  -- salon_direct = 0% commission
  ASSERT (r->>'commission')::numeric = 0,
    format('TEST 3 FAIL: commission should be 0, got %s', r->>'commission');
  ASSERT (r->>'commission_rate')::numeric = 0,
    format('TEST 3 FAIL: commission_rate should be 0, got %s', r->>'commission_rate');

  RAISE NOTICE 'TEST 3 PASSED: cash_direct, salon_direct, 0%% commission';
END $$;

-- =========================================================================
-- TEST 4: Insufficient saldo raises exception
-- =========================================================================
DO $$
DECLARE
  r jsonb;
BEGIN
  UPDATE profiles SET saldo = 10.00 WHERE id = '00000000-0000-0000-0000-000000000001';

  BEGIN
    r := create_booking_with_financials(
      p_user_id        := '00000000-0000-0000-0000-000000000001'::uuid,
      p_business_id    := '00000000-0000-0000-0000-0000000000b1'::uuid,
      p_service_id     := 'svc-test-4',
      p_service_name   := 'Expensive Test',
      p_service_type   := 'expensive',
      p_starts_at      := now() + interval '8 hours',
      p_ends_at        := now() + interval '9 hours',
      p_price          := 9999.00,
      p_payment_method := 'saldo',
      p_booking_source := 'bc_marketplace'
    );
    RAISE EXCEPTION 'TEST 4 FAIL: should have raised insufficient saldo';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%Saldo insuficiente%',
      format('TEST 4 FAIL: expected saldo error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'TEST 4 PASSED: insufficient saldo raises exception';
END $$;

-- =========================================================================
-- TEST 5: Invalid payment method raises exception
-- =========================================================================
DO $$
DECLARE
  r jsonb;
BEGIN
  BEGIN
    r := create_booking_with_financials(
      p_user_id        := '00000000-0000-0000-0000-000000000001'::uuid,
      p_business_id    := '00000000-0000-0000-0000-0000000000b1'::uuid,
      p_service_id     := 'svc-test-5',
      p_service_name   := 'Invalid Method',
      p_service_type   := 'test',
      p_starts_at      := now() + interval '10 hours',
      p_ends_at        := now() + interval '11 hours',
      p_price          := 100.00,
      p_payment_method := 'bitcoin',
      p_booking_source := 'bc_marketplace'
    );
    RAISE EXCEPTION 'TEST 5 FAIL: should have raised invalid method';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM LIKE '%no soportado%',
      format('TEST 5 FAIL: expected unsupported method error, got: %s', SQLERRM);
  END;

  RAISE NOTICE 'TEST 5 PASSED: invalid payment method raises exception';
END $$;

-- Rollback everything — zero prod impact
ROLLBACK;
