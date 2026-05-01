-- Hard-purge of bughunter test businesses left behind by flow cleanup.
--
-- BC directive 2026-05-01: bughunter test residue must be purged completely.
-- The original cleanup soft-deleted (is_active=false + name renamed to
-- "[bughunter-flow cleanup] <ts>") and skipped businesses entirely. Result:
-- 32 zombie business rows owned by the hunter user.
--
-- This migration extends purge_hunter_test_residue() to delete every
-- business whose name starts with "[bughunter-flow " AND owner is a
-- hunter user, walking every FK dependent in dependency order.
--
-- Real businesses have plain names; the bracket-prefix is the test marker.
-- The owner-is-hunter constraint is the second guard so we can never wipe
-- a real customer's salon even if their name accidentally matches.

CREATE OR REPLACE FUNCTION public.purge_test_business(p_business_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Only callable by service_role / admin / superadmin.
  IF auth.role() <> 'service_role' AND NOT EXISTS (
    SELECT 1 FROM profiles
     WHERE id = auth.uid() AND role IN ('admin','superadmin')
  ) THEN
    RAISE EXCEPTION 'admin or service_role required' USING ERRCODE = '42501';
  END IF;

  -- Walk every FK referencing businesses(id), in a safe deletion order.
  -- Order matters where one dependent points at another.

  -- Children with their own children first
  DELETE FROM debt_payments
   WHERE debt_id IN (SELECT id FROM salon_debts WHERE business_id = p_business_id);
  DELETE FROM salon_debts WHERE business_id = p_business_id;

  DELETE FROM payout_identity_checks WHERE business_id = p_business_id;
  DELETE FROM payout_holds WHERE business_id = p_business_id;
  DELETE FROM payout_records WHERE business_id = p_business_id;

  DELETE FROM commission_records WHERE business_id = p_business_id;
  DELETE FROM staff_commissions WHERE business_id = p_business_id;
  DELETE FROM cfdi_records WHERE business_id = p_business_id;
  DELETE FROM tax_withholdings WHERE business_id = p_business_id;
  DELETE FROM sat_monthly_reports WHERE business_id = p_business_id;

  DELETE FROM orders WHERE business_id = p_business_id;
  DELETE FROM product_showcases WHERE business_id = p_business_id;
  DELETE FROM products WHERE business_id = p_business_id;
  DELETE FROM gift_cards WHERE business_id = p_business_id;
  DELETE FROM loyalty_transactions WHERE business_id = p_business_id;

  DELETE FROM business_expenses WHERE business_id = p_business_id;
  DELETE FROM business_clients WHERE business_id = p_business_id;
  DELETE FROM business_closures WHERE business_id = p_business_id;
  DELETE FROM business_imports WHERE business_id = p_business_id;

  DELETE FROM disputes WHERE business_id = p_business_id;
  DELETE FROM reviews WHERE business_id = p_business_id;
  DELETE FROM favorites WHERE business_id = p_business_id;

  DELETE FROM appointments WHERE business_id = p_business_id;
  DELETE FROM walkin_pending_appointments WHERE business_id = p_business_id;
  DELETE FROM salon_walkin_registrations WHERE business_id = p_business_id;

  DELETE FROM portfolio_photos WHERE business_id = p_business_id;
  DELETE FROM staff_schedule_blocks WHERE business_id = p_business_id;
  DELETE FROM staff_link_requests WHERE business_id = p_business_id;
  DELETE FROM staff WHERE business_id = p_business_id;
  DELETE FROM services WHERE business_id = p_business_id;

  DELETE FROM pos_agreements WHERE business_id = p_business_id;
  DELETE FROM automated_message_log WHERE business_id = p_business_id;
  DELETE FROM automated_messages WHERE business_id = p_business_id;
  DELETE FROM businesses_cash_state_log WHERE business_id = p_business_id;

  -- Outreach history pointing at this business as recipient_id (where the
  -- recipient_table is 'businesses'). Soft-coupled — drop the row.
  DELETE FROM bulk_outreach_recipients
   WHERE recipient_table = 'businesses' AND recipient_id = p_business_id;

  -- discovered_salons.registered_business_id is a back-pointer; null it
  -- rather than delete the discovered row (the discovered_salon may pre-date
  -- the test biz).
  UPDATE discovered_salons
     SET registered_business_id = NULL
   WHERE registered_business_id = p_business_id;

  -- Finally the business itself.
  DELETE FROM businesses WHERE id = p_business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.purge_test_business(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.purge_test_business(uuid) IS
  'Hard-deletes a business and every dependent row. admin / superadmin / service_role only. Used by the bughunter test-residue purge — never call on a real customer business.';

-- ─── Extend the residue purge to wipe test businesses ────────────────────
CREATE OR REPLACE FUNCTION public.purge_hunter_test_residue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  hunter_ids uuid[];
  v_saldo_reset numeric := 0;
  v_disputes int := 0;
  v_review_tags int := 0;
  v_reviews int := 0;
  v_appts int := 0;
  v_chat_msgs int := 0;
  v_chat_threads int := 0;
  v_commissions int := 0;
  v_debts int := 0;
  v_taxes int := 0;
  v_test_businesses int := 0;
  rec record;
  biz_rec record;
BEGIN
  IF auth.role() <> 'service_role' AND NOT EXISTS (
    SELECT 1 FROM profiles
     WHERE id = auth.uid() AND role IN ('admin','superadmin')
  ) THEN
    RAISE EXCEPTION 'admin or service_role required' USING ERRCODE = '42501';
  END IF;

  SELECT array_agg(id) INTO hunter_ids
    FROM auth.users
   WHERE email LIKE '%hunter%';

  IF hunter_ids IS NULL OR array_length(hunter_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'note', 'no hunter users');
  END IF;

  -- Reset hunter saldo via idempotent ledger.
  FOR rec IN
    SELECT id, saldo FROM profiles WHERE id = ANY(hunter_ids) AND saldo > 0
  LOOP
    PERFORM increment_saldo(
      p_user_id => rec.id,
      p_amount => -rec.saldo,
      p_reason => 'hunter_test_residue_purge',
      p_idempotency_key => 'purge-' || rec.id || '-' || extract(epoch from now())::bigint
    );
    v_saldo_reset := v_saldo_reset + rec.saldo;
  END LOOP;

  -- User-side residue first (pre-existing behavior).
  DELETE FROM disputes WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_disputes = ROW_COUNT;

  DELETE FROM review_tags
   WHERE review_id IN (SELECT id FROM reviews WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_review_tags = ROW_COUNT;
  DELETE FROM reviews WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_reviews = ROW_COUNT;

  DELETE FROM appointments WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_appts = ROW_COUNT;

  -- chat rows, commission/debt/tax dependents
  DELETE FROM chat_messages
   WHERE thread_id IN (SELECT id FROM chat_threads WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_chat_msgs = ROW_COUNT;
  DELETE FROM chat_threads WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_chat_threads = ROW_COUNT;

  -- Hard-purge bughunter test businesses owned by hunter users.
  -- Marker: name starts with "[bughunter-flow " (cleanup OR test prefix).
  -- The owner-is-hunter constraint prevents wiping a real customer salon
  -- whose name happens to contain the bracket.
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
$$;

GRANT EXECUTE ON FUNCTION public.purge_hunter_test_residue() TO authenticated, service_role;

COMMENT ON FUNCTION public.purge_hunter_test_residue() IS
  'Bughunter test residue purge. Resets hunter saldo, deletes user-side disputes/reviews/appointments/chat, AND hard-deletes test businesses left behind by business-registration cleanup ([bughunter-flow %] name + hunter owner).';
