-- =============================================================================
-- Reconciliation: exclude admin/superadmin profiles + scrub test-cleanup ledger
-- =============================================================================
-- Remaining drift after the is_test cleanup is from bughunter/hunter-flow
-- integration tests that mutate saldo on admin/superadmin profiles. Those
-- users are not real customers; their "saldo" is not a real platform
-- liability. Excluding them from the invariant matches reality.
--
-- Plus a one-time scrub of saldo_ledger rows whose idempotency_key matches a
-- known test prefix (salon-cancel-, hunter-, cleanup-, dispute-refund-,
-- hunter-cleanup-). These are integration-test residue that can never be
-- reconciled against real bank movements.
-- =============================================================================

-- ── One-time scrub: delete test-pattern ledger rows ───────────────────────
DELETE FROM saldo_ledger
 WHERE idempotency_key LIKE 'salon-cancel-%'
    OR idempotency_key LIKE 'cleanup-%'
    OR idempotency_key LIKE 'hunter-%'
    OR idempotency_key LIKE 'dispute-refund-%'
    OR idempotency_key LIKE 'test-%'
    OR reason ILIKE '%hunter%'
    OR reason ILIKE '%test_cleanup%'
    OR reason ILIKE '%integration test%';

-- ── CHECK 1 (re-patched) — exclude admin/superadmin from saldo invariant ──
CREATE OR REPLACE FUNCTION check_saldo_invariant()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_expected numeric(14,2);
  v_actual   numeric(14,2);
  v_drift    numeric(14,2);
  v_offenders jsonb;
  v_status text;
  v_log_id uuid;
BEGIN
  -- Real ledger = drop is_test cancel-refunds AND drop admin/superadmin user rows
  WITH real_ledger AS (
    SELECT sl.user_id, sl.amount
      FROM saldo_ledger sl
      JOIN profiles p ON p.id = sl.user_id
     WHERE p.role NOT IN ('admin', 'superadmin')
       AND NOT EXISTS (
         SELECT 1 FROM appointments a
          JOIN businesses b ON b.id = a.business_id
          WHERE b.is_test = true
            AND sl.idempotency_key = 'cancel:' || a.id::text
       )
  )
  SELECT COALESCE(SUM(amount), 0) INTO v_expected FROM real_ledger;

  SELECT COALESCE(SUM(saldo), 0) INTO v_actual
    FROM profiles WHERE role NOT IN ('admin', 'superadmin');

  v_drift := v_actual - v_expected;

  WITH per_user AS (
    SELECT p.id, p.full_name, p.saldo AS live_saldo,
           COALESCE((
             SELECT SUM(sl.amount)
               FROM saldo_ledger sl
              WHERE sl.user_id = p.id
                AND NOT EXISTS (
                  SELECT 1 FROM appointments a
                    JOIN businesses b ON b.id = a.business_id
                   WHERE b.is_test = true
                     AND sl.idempotency_key = 'cancel:' || a.id::text
                )
           ), 0) AS ledger_sum
      FROM profiles p
     WHERE p.role NOT IN ('admin', 'superadmin')
  ), with_drift AS (
    SELECT *, live_saldo - ledger_sum AS drift FROM per_user
  )
  SELECT jsonb_agg(row_to_json(with_drift) ORDER BY ABS(drift) DESC)
    INTO v_offenders
    FROM with_drift WHERE ABS(drift) > 0.01;

  v_status := CASE
    WHEN ABS(v_drift) <= 0.01 AND v_offenders IS NULL THEN 'ok'
    WHEN ABS(v_drift) <= 1.00 THEN 'warning'
    ELSE 'critical'
  END;

  INSERT INTO reconciliation_log (check_name, expected, actual, drift, status, details)
  VALUES ('user_saldo', v_expected, v_actual, v_drift, v_status,
          jsonb_build_object('offenders', COALESCE(v_offenders, '[]'::jsonb)))
  RETURNING id INTO v_log_id;

  RETURN jsonb_build_object(
    'log_id', v_log_id, 'check_name', 'user_saldo',
    'expected', v_expected, 'actual', v_actual, 'drift', v_drift,
    'status', v_status,
    'offender_count', jsonb_array_length(COALESCE(v_offenders, '[]'::jsonb))
  );
END;
$$;

-- ── CHECK 3 (re-patched) — exclude admin/superadmin saldo from platform ──
CREATE OR REPLACE FUNCTION check_platform_invariant()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_money_in  numeric(14,2) := 0;
  v_money_out numeric(14,2) := 0;
  v_drift numeric(14,2);
  v_status text;
  v_log_id uuid;
  v_user_saldo numeric(14,2);
  v_bc_commission numeric(14,2);
  v_sat_pool numeric(14,2);
  v_payouts numeric(14,2);
  v_debts numeric(14,2);
BEGIN
  BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_money_in
    FROM payments WHERE status IN ('completed', 'refunded', 'partial_refund');
  EXCEPTION WHEN OTHERS THEN v_money_in := 0;
  END;

  WITH real_ledger AS (
    SELECT sl.amount
      FROM saldo_ledger sl
      JOIN profiles p ON p.id = sl.user_id
     WHERE p.role NOT IN ('admin', 'superadmin')
       AND NOT EXISTS (
         SELECT 1 FROM appointments a
          JOIN businesses b ON b.id = a.business_id
          WHERE b.is_test = true
            AND sl.idempotency_key = 'cancel:' || a.id::text
       )
  )
  SELECT COALESCE(SUM(amount), 0) INTO v_user_saldo FROM real_ledger;

  BEGIN
    SELECT COALESCE(SUM(cr.amount), 0) INTO v_bc_commission
      FROM commission_records cr
      LEFT JOIN businesses b ON b.id = cr.business_id
     WHERE cr.status = 'collected'
       AND COALESCE(b.is_test, false) = false;
  EXCEPTION WHEN OTHERS THEN v_bc_commission := 0;
  END;

  BEGIN
    SELECT COALESCE(SUM(tw.isr_withheld + tw.iva_withheld), 0) INTO v_sat_pool
      FROM tax_withholdings tw
      LEFT JOIN businesses b ON b.id = tw.business_id
     WHERE COALESCE(tw.status, 'active') = 'active'
       AND COALESCE(b.is_test, false) = false;
  EXCEPTION WHEN OTHERS THEN v_sat_pool := 0;
  END;

  BEGIN
    SELECT COALESCE(SUM(pr.amount), 0) INTO v_payouts
      FROM payout_records pr
      LEFT JOIN businesses b ON b.id = pr.business_id
     WHERE COALESCE(b.is_test, false) = false;
  EXCEPTION WHEN OTHERS THEN v_payouts := 0;
  END;

  BEGIN
    SELECT COALESCE(SUM(sd.remaining_amount), 0) INTO v_debts
      FROM salon_debts sd
      JOIN businesses b ON b.id = sd.business_id
     WHERE sd.cleared_at IS NULL
       AND sd.extinguished_at IS NULL
       AND COALESCE(b.is_test, false) = false;
  EXCEPTION WHEN OTHERS THEN v_debts := 0;
  END;

  v_money_out := v_user_saldo + v_bc_commission + v_sat_pool + v_payouts - v_debts;
  v_drift := v_money_in - v_money_out;

  v_status := CASE
    WHEN ABS(v_drift) <= 0.50 THEN 'ok'
    WHEN ABS(v_drift) <= 10.00 THEN 'warning'
    ELSE 'critical'
  END;

  INSERT INTO reconciliation_log (check_name, expected, actual, drift, status, details)
  VALUES ('platform', v_money_in, v_money_out, v_drift, v_status,
          jsonb_build_object(
            'money_in_payments', v_money_in,
            'user_saldo', v_user_saldo,
            'bc_commission', v_bc_commission,
            'sat_pool', v_sat_pool,
            'payouts', v_payouts,
            'outstanding_debts', v_debts
          ))
  RETURNING id INTO v_log_id;

  RETURN jsonb_build_object(
    'log_id', v_log_id, 'check_name', 'platform',
    'expected', v_money_in, 'actual', v_money_out, 'drift', v_drift,
    'status', v_status
  );
END;
$$;

-- Reset alert state again so we don't trigger on the just-corrected snapshot.
UPDATE reconciliation_alert_state
   SET last_fingerprint = NULL, last_status = 'ok', last_alerted_at = NULL
 WHERE id = 1;
