-- =============================================================================
-- Reconciliation: alert dedup + is_test isolation
-- =============================================================================
-- Two problems caused last night's WA flood:
--   1. Watchdog fires every cron tick the invariants are still failing. With a
--      15-minute cron and a non-self-healing drift, that's 4 alerts/hour with
--      identical content. WA account block risk + zero new information.
--   2. Drift is entirely from is_test fixtures (Afakename + Salón Test PV +
--      admin-fixture saldo ledger) so the alarm is structurally wrong.
--
-- Fix:
--   A. New table reconciliation_alert_state (singleton). Watchdog computes a
--      fingerprint of (status, drift values, offender ids) and only alerts on
--      transition. Alert again at 24h heartbeat to confirm still-failing.
--   B. Patched invariants exclude is_test businesses + saldo ledger rows that
--      reference is_test business activity (via salon_debts.business_id and
--      saldo_ledger.idempotency_key prefix 'cancel:' joined to a test booking).
-- =============================================================================

-- ── Alert state singleton ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reconciliation_alert_state (
  id smallint PRIMARY KEY DEFAULT 1,
  last_fingerprint text,
  last_status text,
  last_alerted_at timestamptz,
  CHECK (id = 1)
);
INSERT INTO reconciliation_alert_state (id) VALUES (1) ON CONFLICT DO NOTHING;
ALTER TABLE reconciliation_alert_state ENABLE ROW LEVEL SECURITY;
GRANT SELECT, UPDATE, INSERT ON reconciliation_alert_state TO service_role;

-- ── Helper: should_alert(fingerprint, status) ──────────────────────────────
-- Returns true if we should fire the WA alert this cycle. Updates the state
-- atomically so concurrent watchdog calls don't double-alert.
CREATE OR REPLACE FUNCTION should_alert_reconciliation(
  p_fingerprint text,
  p_status text,
  p_heartbeat_hours int DEFAULT 24
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_state RECORD;
  v_should boolean := false;
BEGIN
  SELECT * INTO v_state FROM reconciliation_alert_state WHERE id = 1 FOR UPDATE;

  -- ok → never alert (and clear the prior fingerprint so a re-occurrence of
  -- the same drift triggers a fresh alert).
  IF p_status = 'ok' THEN
    IF v_state.last_fingerprint IS NOT NULL THEN
      UPDATE reconciliation_alert_state
         SET last_fingerprint = NULL, last_status = 'ok', last_alerted_at = NULL
       WHERE id = 1;
    END IF;
    RETURN false;
  END IF;

  -- New fingerprint OR previous was ok → alert.
  IF v_state.last_fingerprint IS DISTINCT FROM p_fingerprint THEN
    v_should := true;
  -- Same fingerprint, but it's been a while — heartbeat reminder.
  ELSIF v_state.last_alerted_at IS NULL
     OR v_state.last_alerted_at < now() - make_interval(hours => p_heartbeat_hours) THEN
    v_should := true;
  END IF;

  IF v_should THEN
    UPDATE reconciliation_alert_state
       SET last_fingerprint = p_fingerprint,
           last_status = p_status,
           last_alerted_at = now()
     WHERE id = 1;
  END IF;

  RETURN v_should;
END;
$$;
GRANT EXECUTE ON FUNCTION should_alert_reconciliation(text, text, int) TO service_role;

-- ── CHECK 1 (patched) — USER SALDO, excluding test-fixture-only ledger ─────
-- A fixture-business cancellation creates a saldo_ledger row credited to the
-- canceller. Those entries make admin/test users drift. Strategy: exclude
-- ledger rows whose idempotency_key 'cancel:<uuid>' references an appointment
-- whose business is is_test=true.
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
  -- Build a CTE of "real" ledger rows: drop entries that are cancel-refunds
  -- of a test-fixture booking. Those won't match a real bank movement.
  WITH real_ledger AS (
    SELECT sl.user_id, sl.amount
      FROM saldo_ledger sl
     WHERE NOT EXISTS (
       SELECT 1 FROM appointments a
        JOIN businesses b ON b.id = a.business_id
        WHERE b.is_test = true
          AND sl.idempotency_key = 'cancel:' || a.id::text
     )
  )
  SELECT COALESCE(SUM(amount), 0) INTO v_expected FROM real_ledger;

  SELECT COALESCE(SUM(saldo), 0) INTO v_actual FROM profiles;
  v_drift := v_actual - v_expected;

  WITH per_user AS (
    SELECT p.id,
           p.full_name,
           p.saldo AS live_saldo,
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

-- ── CHECK 2 (patched) — BUSINESS DEBT excluding is_test ────────────────────
CREATE OR REPLACE FUNCTION check_business_debt_invariant()
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
  SELECT COALESCE(SUM(outstanding_debt), 0) INTO v_expected
    FROM businesses WHERE COALESCE(is_test, false) = false;

  SELECT COALESCE(SUM(sd.remaining_amount), 0) INTO v_actual
    FROM salon_debts sd
    JOIN businesses b ON b.id = sd.business_id
   WHERE sd.cleared_at IS NULL
     AND sd.extinguished_at IS NULL
     AND COALESCE(b.is_test, false) = false;

  v_drift := v_actual - v_expected;

  WITH per_biz AS (
    SELECT b.id, b.name, b.outstanding_debt AS live_debt,
      COALESCE((SELECT SUM(remaining_amount) FROM salon_debts
                WHERE business_id = b.id
                  AND cleared_at IS NULL
                  AND extinguished_at IS NULL), 0) AS computed_debt
    FROM businesses b
    WHERE COALESCE(b.is_test, false) = false
  )
  SELECT jsonb_agg(row_to_json(per_biz) ORDER BY ABS(computed_debt - live_debt) DESC)
    INTO v_offenders
    FROM per_biz
   WHERE ABS(computed_debt - live_debt) > 0.01;

  v_status := CASE
    WHEN ABS(v_drift) <= 0.01 AND v_offenders IS NULL THEN 'ok'
    WHEN ABS(v_drift) <= 1.00 THEN 'warning'
    ELSE 'critical'
  END;

  INSERT INTO reconciliation_log (check_name, expected, actual, drift, status, details)
  VALUES ('business_debt', v_expected, v_actual, v_drift, v_status,
          jsonb_build_object('offenders', COALESCE(v_offenders, '[]'::jsonb)))
  RETURNING id INTO v_log_id;

  RETURN jsonb_build_object(
    'log_id', v_log_id, 'check_name', 'business_debt',
    'expected', v_expected, 'actual', v_actual, 'drift', v_drift,
    'status', v_status,
    'offender_count', jsonb_array_length(COALESCE(v_offenders, '[]'::jsonb))
  );
END;
$$;

-- ── CHECK 3 (patched) — PLATFORM excluding is_test contributions ──────────
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
  -- Money in: payments (is_test gating already at appointment level — payments
  -- table doesn't carry the flag directly; rely on the test_business_isolation
  -- triggers to keep payments clean for fixtures going forward).
  BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_money_in
    FROM payments
    WHERE status IN ('completed', 'refunded', 'partial_refund');
  EXCEPTION WHEN OTHERS THEN v_money_in := 0;
  END;

  -- User saldo: drop test-fixture cancel-refund credits (mirror saldo invariant).
  WITH real_ledger AS (
    SELECT sl.amount
      FROM saldo_ledger sl
     WHERE NOT EXISTS (
       SELECT 1 FROM appointments a
        JOIN businesses b ON b.id = a.business_id
        WHERE b.is_test = true
          AND sl.idempotency_key = 'cancel:' || a.id::text
     )
  )
  SELECT COALESCE(SUM(amount), 0) INTO v_user_saldo FROM real_ledger;

  -- BC commission excludes commission_records linked to is_test businesses.
  BEGIN
    SELECT COALESCE(SUM(cr.amount), 0) INTO v_bc_commission
      FROM commission_records cr
      LEFT JOIN businesses b ON b.id = cr.business_id
     WHERE cr.status = 'collected'
       AND COALESCE(b.is_test, false) = false;
  EXCEPTION WHEN OTHERS THEN v_bc_commission := 0;
  END;

  -- SAT pool excludes is_test withholdings (the trigger blocks new ones; legacy
  -- rows might still exist).
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

-- ── Cleanup: clear is_test-induced drift in real tables ────────────────────
-- a) Mark is_test salon_debts as cleared so the denorm cache doesn't fight us.
UPDATE salon_debts sd
   SET cleared_at = COALESCE(sd.cleared_at, now()),
       remaining_amount = 0
  FROM businesses b
 WHERE sd.business_id = b.id
   AND b.is_test = true
   AND sd.cleared_at IS NULL;

-- b) Reset is_test business outstanding_debt cache to 0.
UPDATE businesses SET outstanding_debt = 0 WHERE is_test = true AND outstanding_debt <> 0;

-- c) Delete saldo_ledger rows whose idempotency_key references an is_test booking.
--    Those credits were never real — admin/test user got phantom saldo from
--    cancelling fixture bookings.
DELETE FROM saldo_ledger sl
 WHERE EXISTS (
   SELECT 1 FROM appointments a
    JOIN businesses b ON b.id = a.business_id
    WHERE b.is_test = true
      AND sl.idempotency_key = 'cancel:' || a.id::text
 );

-- Reset alert state so the next watchdog tick isn't held hostage by yesterday's
-- fingerprint.
UPDATE reconciliation_alert_state
   SET last_fingerprint = NULL, last_status = 'ok', last_alerted_at = NULL
 WHERE id = 1;
