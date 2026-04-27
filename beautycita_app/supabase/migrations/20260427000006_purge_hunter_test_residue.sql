-- Belt-and-suspenders cleanup for hunter test residue.
--
-- Per-flow cleanup is the first line of defense, but anything that throws
-- before its cleanup step leaks rows. This RPC is the second line — service
-- role only, callable from the bughunter runner after every flow batch as
-- a final purge.
--
-- Scope:
--   * profiles.saldo > 0 for any hunter+* email → reset to 0 via the
--     idempotent ledger RPC so the audit trail stays balanced.
--   * disputes / reviews / review_tags / appointments / chat_messages /
--     chat_threads / commission_records / salon_debts / tax_withholdings
--     attributable to hunter users → deleted (children before parents).
--
-- Does NOT touch: businesses (the [HUNTER-TEST] partner biz is a fixture,
-- intentionally durable), products (durable), staff (durable).

CREATE OR REPLACE FUNCTION public.purge_hunter_test_residue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  hunter_ids uuid[];
  v_saldo_reset numeric := 0;
  v_disputes int;
  v_review_tags int;
  v_reviews int;
  v_appts int;
  v_chat_msgs int;
  v_chat_threads int;
  v_commissions int;
  v_debts int;
  v_taxes int;
  rec record;
BEGIN
  -- Admin / superadmin / service_role only. The hunter user is admin
  -- so the bughunter runner can call this directly via pgRpc.
  IF auth.role() <> 'service_role' AND NOT EXISTS (
    SELECT 1 FROM profiles
     WHERE id = auth.uid()
       AND role IN ('admin','superadmin')
  ) THEN
    RAISE EXCEPTION 'admin or service_role required' USING ERRCODE = '42501';
  END IF;

  SELECT array_agg(id) INTO hunter_ids
    FROM auth.users
   WHERE email LIKE '%hunter%';

  IF hunter_ids IS NULL OR array_length(hunter_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'note', 'no hunter users');
  END IF;

  -- Reset saldo on every hunter row that has a balance, via idempotent ledger.
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

  -- Children of disputes (none in current schema) → disputes themselves
  DELETE FROM disputes WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_disputes = ROW_COUNT;

  -- review_tags (children) → reviews
  DELETE FROM review_tags
   WHERE review_id IN (SELECT id FROM reviews WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_review_tags = ROW_COUNT;
  DELETE FROM reviews WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_reviews = ROW_COUNT;

  -- Appointment children before appointments.
  DELETE FROM commission_records
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_commissions = ROW_COUNT;
  DELETE FROM salon_debts
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_debts = ROW_COUNT;
  DELETE FROM tax_withholdings
   WHERE appointment_id IN (SELECT id FROM appointments WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_taxes = ROW_COUNT;
  DELETE FROM appointments WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_appts = ROW_COUNT;

  -- Chat threads + messages.
  DELETE FROM chat_messages
   WHERE thread_id IN (SELECT id FROM chat_threads WHERE user_id = ANY(hunter_ids));
  GET DIAGNOSTICS v_chat_msgs = ROW_COUNT;
  DELETE FROM chat_threads WHERE user_id = ANY(hunter_ids);
  GET DIAGNOSTICS v_chat_threads = ROW_COUNT;

  -- Orders + their dependents on the [HUNTER-TEST] partner biz (the
  -- partner sells but the hunter is the buyer; if buyer_id leaks too,
  -- catch via business filter as well).
  DELETE FROM commission_records
   WHERE order_id IN (SELECT id FROM orders WHERE buyer_id = ANY(hunter_ids));
  DELETE FROM salon_debts
   WHERE order_id IN (SELECT id FROM orders WHERE buyer_id = ANY(hunter_ids));
  DELETE FROM tax_withholdings
   WHERE order_id IN (SELECT id FROM orders WHERE buyer_id = ANY(hunter_ids));
  DELETE FROM orders WHERE buyer_id = ANY(hunter_ids);

  RETURN jsonb_build_object(
    'ok', true,
    'saldo_reset', v_saldo_reset,
    'disputes', v_disputes,
    'review_tags', v_review_tags,
    'reviews', v_reviews,
    'appointments', v_appts,
    'commission_records', v_commissions,
    'salon_debts', v_debts,
    'tax_withholdings', v_taxes,
    'chat_messages', v_chat_msgs,
    'chat_threads', v_chat_threads
  );
END;
$$;

REVOKE ALL ON FUNCTION public.purge_hunter_test_residue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_hunter_test_residue() TO authenticated, service_role;
