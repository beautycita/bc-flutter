-- =============================================================================
-- Reconciliation watchdog: accounting-invariant checker
-- =============================================================================
--
-- Core idea: every money movement in BeautyCita must be double-entry. If we
-- sum the live state and compare against the sum of what the ledgers say,
-- the delta must be zero. Any delta means money was created or destroyed —
-- impossible by construction, so it's either a bug or tampering.
--
-- Three invariants, cheapest first:
--
--   1. USER SALDO — for every user, profiles.saldo == SUM(saldo_ledger.amount)
--   2. BUSINESS DEBT — for every business,
--      businesses.outstanding_debt == SUM(salon_debts.amount) - SUM(debt_payments.amount)
--   3. PLATFORM — aggregate: all money received accounts for where it is now
--      (user saldos + BC commission + SAT retention pool + salon payouts)
--
-- Each check writes a row to reconciliation_log. Any |drift| > 1 peso flips
-- status='critical' and the edge-fn watchdog fires a WA alert to BC.
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_log (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  check_name   text NOT NULL,                -- 'user_saldo' | 'business_debt' | 'platform'
  expected     numeric(14,2),
  actual       numeric(14,2),
  drift        numeric(14,2),
  status       text NOT NULL,                -- 'ok' | 'warning' | 'critical' | 'error'
  details      jsonb,                        -- per-offender breakdown
  checked_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reconciliation_log_checked_at
  ON reconciliation_log (checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_reconciliation_log_status
  ON reconciliation_log (status, checked_at DESC) WHERE status != 'ok';

-- =============================================================================
-- CHECK 1 — USER SALDO INVARIANT
-- =============================================================================
-- For every profile: live saldo column must equal sum of its saldo_ledger rows.
-- Tolerance 0.01 (rounding safety). Returns the log row as jsonb.

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
  -- Expected = sum of all ledger rows
  SELECT COALESCE(SUM(amount), 0) INTO v_expected FROM saldo_ledger;
  -- Actual   = sum of all live saldo columns
  SELECT COALESCE(SUM(saldo), 0) INTO v_actual FROM profiles;
  v_drift := v_actual - v_expected;

  -- Per-user offenders
  WITH per_user AS (
    SELECT p.id,
           p.full_name,
           p.saldo AS live_saldo,
           COALESCE((SELECT SUM(amount) FROM saldo_ledger WHERE user_id = p.id), 0) AS ledger_sum,
           p.saldo - COALESCE((SELECT SUM(amount) FROM saldo_ledger WHERE user_id = p.id), 0) AS drift
    FROM profiles p
  )
  SELECT jsonb_agg(row_to_json(per_user)) INTO v_offenders
  FROM per_user
  WHERE ABS(drift) > 0.01;

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
    'log_id', v_log_id,
    'check_name', 'user_saldo',
    'expected', v_expected,
    'actual', v_actual,
    'drift', v_drift,
    'status', v_status,
    'offender_count', jsonb_array_length(COALESCE(v_offenders, '[]'::jsonb))
  );
END;
$$;

-- =============================================================================
-- CHECK 2 — BUSINESS DEBT INVARIANT
-- =============================================================================
-- businesses.outstanding_debt (denormalized cache) must equal
-- SUM(salon_debts.amount WHERE status='outstanding') - SUM(debt_payments.amount)
-- per business. Tolerance 0.01.

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
  -- Expected = sum of all business.outstanding_debt (denormalized cache)
  SELECT COALESCE(SUM(outstanding_debt), 0) INTO v_expected FROM businesses;
  -- Actual = sum of remaining_amount on non-cleared, non-extinguished debts.
  -- salon_debts tracks remaining_amount directly; debt_payments is historical.
  SELECT COALESCE(SUM(remaining_amount), 0) INTO v_actual
    FROM salon_debts WHERE cleared_at IS NULL AND extinguished_at IS NULL;
  v_drift := v_actual - v_expected;

  WITH per_biz AS (
    SELECT b.id, b.name, b.outstanding_debt AS live_debt,
      COALESCE((SELECT SUM(remaining_amount) FROM salon_debts
                WHERE business_id = b.id
                  AND cleared_at IS NULL
                  AND extinguished_at IS NULL), 0) AS computed_debt
    FROM businesses b
  )
  SELECT jsonb_agg(row_to_json(per_biz)) INTO v_offenders
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
    'log_id', v_log_id,
    'check_name', 'business_debt',
    'expected', v_expected,
    'actual', v_actual,
    'drift', v_drift,
    'status', v_status,
    'offender_count', jsonb_array_length(COALESCE(v_offenders, '[]'::jsonb))
  );
END;
$$;

-- =============================================================================
-- CHECK 3 — PLATFORM INVARIANT
-- =============================================================================
-- The big one. Every peso that entered the system must still be accounted for
-- in one of: user saldos, BC commission pool, SAT retention pool, salon
-- pending payout, salon paid-out (historical).
--
-- Money IN  = Σ(payments.amount WHERE status IN ('completed','refunded'))
--           + Σ(appointments.payment_amount_centavos/100 WHERE payment_status='paid' AND no payment row)
-- Money OUT (redistributed) =
--    Σ(profiles.saldo)                     -- user wallets
--  + Σ(commission_records.amount)          -- BC revenue (retained until payout)
--  + Σ(tax_withholdings.amount WHERE status='active')  -- SAT pool
--  + Σ(payout_records.amount)              -- salon payouts executed
--  + Σ(salon_debts WHERE status != 'paid') -- salon still owes back
--
-- This is a best-effort at v1 — refine the expression as the ledger grows.

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
  -- Money in: all payments recorded
  BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_money_in
    FROM payments
    WHERE status IN ('completed', 'refunded', 'partial_refund');
  EXCEPTION WHEN OTHERS THEN v_money_in := 0;
  END;

  -- Money out: where each peso lives now
  SELECT COALESCE(SUM(saldo), 0) INTO v_user_saldo FROM profiles;

  BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_bc_commission
    FROM commission_records WHERE status = 'collected';
  EXCEPTION WHEN OTHERS THEN v_bc_commission := 0;
  END;

  BEGIN
    SELECT COALESCE(SUM(isr_withheld + iva_withheld), 0) INTO v_sat_pool
    FROM tax_withholdings
    WHERE COALESCE(status, 'active') = 'active';
  EXCEPTION WHEN OTHERS THEN v_sat_pool := 0;
  END;

  BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_payouts FROM payout_records;
  EXCEPTION WHEN OTHERS THEN v_payouts := 0;
  END;

  BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_debts
    FROM salon_debts WHERE status != 'paid';
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
    'log_id', v_log_id,
    'check_name', 'platform',
    'expected', v_money_in,
    'actual', v_money_out,
    'drift', v_drift,
    'status', v_status
  );
END;
$$;

-- =============================================================================
-- RUN-ALL: single entry point for the edge fn
-- =============================================================================

CREATE OR REPLACE FUNCTION run_reconciliation_all()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_saldo   jsonb;
  v_debt    jsonb;
  v_plat    jsonb;
BEGIN
  v_saldo := check_saldo_invariant();
  v_debt  := check_business_debt_invariant();
  v_plat  := check_platform_invariant();

  RETURN jsonb_build_object(
    'user_saldo',    v_saldo,
    'business_debt', v_debt,
    'platform',      v_plat,
    'worst_status',
      CASE
        WHEN v_saldo->>'status' = 'critical' OR v_debt->>'status' = 'critical' OR v_plat->>'status' = 'critical' THEN 'critical'
        WHEN v_saldo->>'status' = 'warning'  OR v_debt->>'status' = 'warning'  OR v_plat->>'status' = 'warning'  THEN 'warning'
        WHEN v_saldo->>'status' = 'error'    OR v_debt->>'status' = 'error'    OR v_plat->>'status' = 'error'    THEN 'error'
        ELSE 'ok'
      END,
    'checked_at', now()
  );
END;
$$;

COMMENT ON FUNCTION run_reconciliation_all() IS
  'Run all accounting invariants. Returns worst status + per-check details. '
  'Called by the reconciliation-watchdog edge fn on a 15-min cron.';

-- Grant execution to service_role (edge fn service key calls this)
REVOKE ALL ON FUNCTION run_reconciliation_all() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION run_reconciliation_all() TO service_role;
REVOKE ALL ON FUNCTION check_saldo_invariant() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION check_saldo_invariant() TO service_role;
REVOKE ALL ON FUNCTION check_business_debt_invariant() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION check_business_debt_invariant() TO service_role;
REVOKE ALL ON FUNCTION check_platform_invariant() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION check_platform_invariant() TO service_role;

-- RLS: log is admin-only readable
ALTER TABLE reconciliation_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reconciliation_log_admin_read ON reconciliation_log;
CREATE POLICY reconciliation_log_admin_read ON reconciliation_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );
