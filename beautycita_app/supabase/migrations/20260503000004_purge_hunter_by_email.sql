-- =============================================================================
-- 20260503000004 — purge_hunter_test_residue identifies hunter by email
-- =============================================================================
-- The purge function selected hunter users by `username ILIKE 'hunter%'`,
-- but bughunter test users get auto-generated cute usernames per BC's
-- username rules (e.g. 'dewyViolet'). Email is the stable identifier:
-- 'hunter+test@beautycita.com', 'hunter+partner@beautycita.com'.
--
-- Found 2026-05-03: bughunter ran flows tonight against Salon Studio Kriket
-- (the only salon meeting curate's gates after I flipped its bypass+verified
-- flags), creating 21 commission_records + 10 salon_debts attached to that
-- real salon. End-of-suite cleanup left them all behind because none of the
-- hunter users had a 'hunter%' username. Doc's accounting-invariant watchdog
-- fired with platform drift 3174.50 + business_debt drift 3395.00.
--
-- Also adds an "orphan ledger" sweep: commission_records / tax_withholdings /
-- salon_debts whose appointment_id has been deleted (purge runs in-order,
-- so this only fires if a previous run left orphans behind).
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
  v_orphan_commissions int := 0;
  v_orphan_taxes       int := 0;
  v_orphan_debts       int := 0;
  biz_rec record;
BEGIN
  -- Hunter users identified by EMAIL pattern (stable across username
  -- regeneration). Username pattern would miss 'dewyViolet'-style auto-
  -- generated names.
  SELECT array_agg(u.id)
    INTO hunter_ids
    FROM auth.users u
   WHERE u.email ILIKE 'hunter%@beautycita.com'
      OR u.email ILIKE 'hunter+%';
  IF hunter_ids IS NULL THEN hunter_ids := ARRAY[]::uuid[]; END IF;

  -- Reset saldo so cumulative test top-ups don't drift.
  UPDATE profiles SET saldo = 0 WHERE id = ANY(hunter_ids) AND saldo <> 0;
  GET DIAGNOSTICS v_saldo_reset = ROW_COUNT;

  -- Order matters: anything that FK-references appointments must go first,
  -- then disputes/reviews (they FK reviews/appointments), then appointments,
  -- then chat. If you add a new dependent on appointments, add its DELETE
  -- HERE — above the appointment delete — not below.
  -- tax_withholdings is protected by sat_retention_guard (CFF Art. 30,
  -- 5-year retention). Even test rows can't be deleted. Decouple instead:
  -- set appointment_id = NULL so the FK no longer blocks the appointment
  -- delete below. The tax row stays in the ledger; sat_pool already
  -- excludes it via status filter.
  UPDATE tax_withholdings
     SET appointment_id = NULL
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_taxes = ROW_COUNT;

  DELETE FROM commission_records
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_commissions = ROW_COUNT;

  -- salon_debts: extinguish (audit trail) AND null the appointment_id
  -- so the FK no longer blocks the appointment delete below. The
  -- reconciliation watchdog only counts debts WHERE extinguished_at IS
  -- NULL, so this clears the invariant.
  UPDATE salon_debts
     SET extinguished_at = COALESCE(extinguished_at, now()),
         extinguished_reason = COALESCE(extinguished_reason, 'hunter test residue'),
         appointment_id = NULL
   WHERE (extinguished_at IS NULL OR appointment_id IS NOT NULL)
     AND appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
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

  -- Orphan ledger sweep: prior buggy runs left commission_records /
  -- tax_withholdings / unextinguished salon_debts referencing now-deleted
  -- appointments. Catch them all in one shot.
  DELETE FROM commission_records cr
   WHERE NOT EXISTS (SELECT 1 FROM appointments a WHERE a.id = cr.appointment_id);
  GET DIAGNOSTICS v_orphan_commissions = ROW_COUNT;

  -- Same SAT-retention rule: NULL the appointment_id rather than DELETE.
  UPDATE tax_withholdings tw
     SET appointment_id = NULL
   WHERE tw.appointment_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM appointments a WHERE a.id = tw.appointment_id);
  GET DIAGNOSTICS v_orphan_taxes = ROW_COUNT;

  UPDATE salon_debts sd
     SET extinguished_at = COALESCE(extinguished_at, now()),
         extinguished_reason = COALESCE(extinguished_reason, 'orphan: appointment deleted'),
         appointment_id = NULL
   WHERE sd.appointment_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM appointments a WHERE a.id = sd.appointment_id);
  GET DIAGNOSTICS v_orphan_debts = ROW_COUNT;

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
    'test_businesses', v_test_businesses,
    'orphan_commissions', v_orphan_commissions,
    'orphan_taxes', v_orphan_taxes,
    'orphan_debts', v_orphan_debts
  );
END;
$function$;
