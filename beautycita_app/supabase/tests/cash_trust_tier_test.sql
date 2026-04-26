-- =============================================================================
-- Cash trust tier — integration test (SAVEPOINT/ROLLBACK, no prod artifacts)
-- =============================================================================
-- Run with:
--   docker exec -i supabase-db psql -U postgres -d postgres < cash_trust_tier_test.sql
-- All assertions must succeed; final ROLLBACK leaves DB unchanged.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_biz_id      uuid := gen_random_uuid();
  v_owner_id    uuid;
  v_user_id     uuid;
  v_min_tx      int;
  v_threshold   numeric;
  v_result      record;
  v_eligible    boolean;
  v_blocked     boolean;
  v_debt_id     uuid;
  v_passes      int := 0;
  v_failures    text[] := ARRAY[]::text[];
BEGIN
  -- Pick a random existing profile to act as owner + customer for FKs.
  SELECT id INTO v_owner_id FROM profiles LIMIT 1;
  IF v_owner_id IS NULL THEN
    RAISE NOTICE 'no profiles in DB — skipping test';
    RETURN;
  END IF;
  v_user_id := v_owner_id;

  v_min_tx := COALESCE((SELECT value::int FROM app_config WHERE key = 'cash_trust_min_tx'), 50);
  v_threshold := COALESCE((SELECT value::numeric FROM app_config WHERE key = 'cash_block_tax_debt_threshold'), 1000);

  -- ── Setup: create non-test business ──────────────────────────────────────
  INSERT INTO businesses (id, owner_id, name, city, state, country, is_active, is_test)
  VALUES (v_biz_id, v_owner_id, 'CashTrust Test Salon', 'Test City', 'Jalisco', 'MX', true, false);

  -- ── T1: zero tx → not eligible ───────────────────────────────────────────
  SELECT * INTO v_result FROM compute_cash_eligibility(v_biz_id);
  IF v_result.out_is_eligible = false AND v_result.out_is_blocked = false AND v_result.out_tx_count = 0 THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, format('T1: expected (eligible=f, blocked=f, tx=0), got (%s,%s,%s)',
      v_result.out_is_eligible, v_result.out_is_blocked, v_result.out_tx_count));
  END IF;

  -- ── T2: just below threshold → still not eligible ────────────────────────
  INSERT INTO appointments (
    user_id, business_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method, booking_source
  )
  SELECT
    v_user_id, v_biz_id, 'Test Service', 'haircut',
    now() - interval '1 day' - (g || ' minutes')::interval,
    now() - interval '1 day' - (g || ' minutes')::interval + interval '30 minutes',
    100, 'confirmed', 'paid', 'saldo', 'bc_marketplace'
  FROM generate_series(1, v_min_tx - 1) g;

  SELECT * INTO v_result FROM compute_cash_eligibility(v_biz_id);
  IF v_result.out_is_eligible = false AND v_result.out_tx_count = v_min_tx - 1 THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, format('T2: expected (eligible=f, tx=%s), got (%s,%s)',
      v_min_tx - 1, v_result.out_is_eligible, v_result.out_tx_count));
  END IF;

  -- ── T3: cross threshold → activated transition ──────────────────────────
  INSERT INTO appointments (
    user_id, business_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method, booking_source
  ) VALUES (
    v_user_id, v_biz_id, 'Test Service', 'haircut',
    now() - interval '2 hours', now() - interval '90 minutes',
    100, 'confirmed', 'paid', 'saldo', 'bc_marketplace'
  );

  SELECT * INTO v_result FROM compute_cash_eligibility(v_biz_id);
  IF v_result.out_is_eligible = true AND v_result.out_transition = 'activated' AND v_result.out_tx_count >= v_min_tx THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, format('T3: expected (eligible=t, transition=activated, tx>=%s), got (%s,%s,%s)',
      v_min_tx, v_result.out_is_eligible, v_result.out_transition, v_result.out_tx_count));
  END IF;

  -- ── T4: re-run → no duplicate transition ────────────────────────────────
  SELECT * INTO v_result FROM compute_cash_eligibility(v_biz_id);
  IF v_result.out_is_eligible = true AND v_result.out_transition IS NULL THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, format('T4: expected (eligible=t, transition=NULL), got (%s,%s)',
      v_result.out_is_eligible, v_result.out_transition));
  END IF;

  -- ── T5: tax debt below threshold → still eligible ───────────────────────
  INSERT INTO salon_debts (business_id, original_amount, remaining_amount, debt_type, reason)
  VALUES (v_biz_id, v_threshold - 1, v_threshold - 1, 'tax_obligation', 'test_below_threshold');

  SELECT * INTO v_result FROM compute_cash_eligibility(v_biz_id);
  IF v_result.out_is_eligible = true AND v_result.out_is_blocked = false THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, format('T5: expected (eligible=t, blocked=f), got (%s,%s)',
      v_result.out_is_eligible, v_result.out_is_blocked));
  END IF;

  -- ── T6: tax debt at threshold → suspended ────────────────────────────────
  INSERT INTO salon_debts (business_id, original_amount, remaining_amount, debt_type, reason)
  VALUES (v_biz_id, 100, 100, 'tax_obligation', 'test_push_over');

  SELECT * INTO v_result FROM compute_cash_eligibility(v_biz_id);
  IF v_result.out_is_eligible = false AND v_result.out_is_blocked = true AND v_result.out_transition = 'suspended' THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, format('T6: expected (eligible=f, blocked=t, transition=suspended), got (%s,%s,%s)',
      v_result.out_is_eligible, v_result.out_is_blocked, v_result.out_transition));
  END IF;

  -- ── T7: customer-side gate via is_cash_eligible() ───────────────────────
  v_eligible := is_cash_eligible(v_biz_id);
  IF v_eligible = false THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, 'T7: is_cash_eligible should be false when blocked');
  END IF;

  -- ── T8: clear all tax debt → trigger fires → reactivated ────────────────
  UPDATE salon_debts SET remaining_amount = 0
   WHERE business_id = v_biz_id AND debt_type = 'tax_obligation';

  -- The trigger should have already fired and unblocked. Confirm via direct read.
  SELECT cash_blocked_at IS NULL AND cash_eligible_at IS NOT NULL
    INTO v_eligible
    FROM businesses WHERE id = v_biz_id;
  IF v_eligible THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, 'T8: trigger did not reactivate after debt cleared');
  END IF;

  -- ── T9: state log fingerprints unique (no duplicate emails) ─────────────
  PERFORM 1 FROM (
    SELECT state_fingerprint, COUNT(*) c
      FROM businesses_cash_state_log
     WHERE business_id = v_biz_id
     GROUP BY state_fingerprint HAVING COUNT(*) > 1
  ) s;
  IF NOT FOUND THEN
    v_passes := v_passes + 1;
  ELSE
    v_failures := array_append(v_failures, 'T9: duplicate state_fingerprint detected');
  END IF;

  -- ── Summary ─────────────────────────────────────────────────────────────
  RAISE NOTICE 'cash_trust_tier_test: % passed, % failed', v_passes, array_length(v_failures, 1);
  IF array_length(v_failures, 1) > 0 THEN
    FOREACH v_blocked IN ARRAY ARRAY[true] LOOP NULL; END LOOP; -- silence unused var
    RAISE EXCEPTION 'cash_trust_tier_test FAILED: %', array_to_string(v_failures, ' | ');
  END IF;
END $$;

ROLLBACK;
