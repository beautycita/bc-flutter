-- =============================================================================
-- 20260503000003 — purge_hunter_test_residue: delete dependents before parents
-- =============================================================================
-- The end-of-suite cleanup tried to delete appointments before deleting the
-- tax_withholdings / commission_records / salon_debts rows that FK-reference
-- them. Result: 23503 FK violation, residue accumulates across runs.
--
-- This rewrite reorders the DELETEs so dependents go first, then appointments.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.purge_hunter_test_residue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  hunter_ids uuid[];
  v_saldo_reset      int := 0;
  v_disputes         int := 0;
  v_review_tags      int := 0;
  v_reviews          int := 0;
  v_appts            int := 0;
  v_chat_msgs        int := 0;
  v_chat_threads     int := 0;
  v_commissions      int := 0;
  v_debts            int := 0;
  v_taxes            int := 0;
  v_test_businesses  int := 0;
  biz_rec record;
BEGIN
  -- Anyone whose username starts with hunter test prefixes.
  SELECT array_agg(id) INTO hunter_ids
    FROM profiles
   WHERE username ILIKE 'hunter%' OR username ILIKE '%hunter-test%';
  IF hunter_ids IS NULL THEN hunter_ids := ARRAY[]::uuid[]; END IF;

  -- Reset saldo so cumulative test top-ups don't drift.
  UPDATE profiles SET saldo = 0 WHERE id = ANY(hunter_ids) AND saldo <> 0;
  GET DIAGNOSTICS v_saldo_reset = ROW_COUNT;

  -- Order matters: anything that FK-references appointments must go first,
  -- then disputes/reviews (they FK reviews/appointments), then appointments,
  -- then chat. If you add a new dependent on appointments, add its DELETE
  -- HERE — above the appointment delete — not below.
  DELETE FROM tax_withholdings
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_taxes = ROW_COUNT;

  DELETE FROM commission_records
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_commissions = ROW_COUNT;

  DELETE FROM salon_debts
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_debts = ROW_COUNT;

  DELETE FROM disputes WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_disputes = ROW_COUNT;

  DELETE FROM review_tags
   WHERE review_id IN (SELECT id FROM reviews WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_review_tags = ROW_COUNT;

  DELETE FROM reviews WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_reviews = ROW_COUNT;

  DELETE FROM appointments WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_appts = ROW_COUNT;

  DELETE FROM chat_messages
   WHERE thread_id IN (SELECT id FROM chat_threads WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_chat_msgs = ROW_COUNT;

  DELETE FROM chat_threads WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_chat_threads = ROW_COUNT;

  -- Hard-purge bughunter test businesses owned by hunter users.
  FOR biz_rec IN
    SELECT id FROM businesses
     WHERE owner_id = ANY(hunter_ids)
       AND (name LIKE '[bughunter-flow %' OR name LIKE '[hunter-test%')
  LOOP
    PERFORM purge_test_business(biz_rec.id);
    v_test_businesses := v_test_businesses + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'saldo_reset', v_saldo_reset,
    'disputes', v_disputes,
    'review_tags', v_review_tags,
    'reviews', v_reviews,
    'appointments', v_appts,
    'chat_messages', v_chat_msgs,
    'chat_threads', v_chat_threads,
    'commissions', v_commissions,
    'debts', v_debts,
    'taxes', v_taxes,
    'test_businesses', v_test_businesses
  );
END;
$function$;
