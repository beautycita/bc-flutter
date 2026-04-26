-- =============================================================================
-- PLATFORM FINANCIAL RESET — wipe all money state to zero
-- =============================================================================
-- Kriket directive 2026-04-26: zero salons / zero customers in production.
-- All saldo, debts, ledger entries, withholdings, commissions, gift cards,
-- loyalty points, orders, disputes, payment intents, appointments, and
-- cash-trust state to date are test fixtures. Reset everything to a clean
-- slate so the platform's books reconcile to zero before real onboarding.
--
-- This is destructive. There is no down — once a row is deleted there is no
-- way back without restoring from backup.
-- =============================================================================

BEGIN;

-- SAT retention guard normally blocks DELETE on tax_withholdings (CFF Art. 30
-- requires ≥5y retention). Cold-start reset bypasses it — there are no real
-- transactions to retain.
SET LOCAL app.sat_unlock = 'yes-i-really-do';

-- ── 1. Money-related ledgers (dependent rows first to avoid FK violations) ──
DELETE FROM debt_payments;
DELETE FROM salon_debts;
DELETE FROM commission_records;
DELETE FROM tax_withholdings;
DELETE FROM staff_commissions;
DELETE FROM sat_monthly_reports;
DELETE FROM businesses_cash_state_log;
DELETE FROM saldo_ledger;
DELETE FROM loyalty_transactions;
DELETE FROM gift_cards;

-- ── 2. Transactional rows that carry money ─────────────────────────────────
DELETE FROM disputes;
DELETE FROM orders;
DELETE FROM payments;
DELETE FROM stripe_webhook_events;
DELETE FROM appointments;

-- ── 3. Reset denorm fields on profiles + businesses ────────────────────────
UPDATE profiles
   SET saldo = 0,
       updated_at = now()
 WHERE saldo IS DISTINCT FROM 0;

-- loyalty_points lives on business_clients, not profiles. Reset there too.
UPDATE business_clients
   SET loyalty_points = 0,
       updated_at = now()
 WHERE loyalty_points IS DISTINCT FROM 0;

UPDATE businesses
   SET outstanding_debt = 0,
       cash_eligible_at = NULL,
       cash_blocked_at = NULL,
       cash_block_reason = NULL,
       cash_tx_count_cached = 0,
       updated_at = now();

-- ── 4. Verify zero state ───────────────────────────────────────────────────
DO $$
DECLARE
  v_saldo_total numeric;
  v_ledger_count bigint;
  v_appt_count bigint;
  v_order_count bigint;
  v_debt_count bigint;
  v_tax_count bigint;
  v_comm_count bigint;
BEGIN
  SELECT COALESCE(SUM(saldo), 0) INTO v_saldo_total FROM profiles;
  SELECT COUNT(*) INTO v_ledger_count FROM saldo_ledger;
  SELECT COUNT(*) INTO v_appt_count FROM appointments;
  SELECT COUNT(*) INTO v_order_count FROM orders;
  SELECT COUNT(*) INTO v_debt_count FROM salon_debts;
  SELECT COUNT(*) INTO v_tax_count FROM tax_withholdings;
  SELECT COUNT(*) INTO v_comm_count FROM commission_records;

  IF v_saldo_total <> 0 THEN
    RAISE EXCEPTION 'RESET FAILED: profiles.saldo total = %, expected 0', v_saldo_total;
  END IF;
  IF v_ledger_count > 0 OR v_appt_count > 0 OR v_order_count > 0
     OR v_debt_count > 0 OR v_tax_count > 0 OR v_comm_count > 0 THEN
    RAISE EXCEPTION 'RESET FAILED: residual rows ledger=% appt=% order=% debt=% tax=% comm=%',
      v_ledger_count, v_appt_count, v_order_count, v_debt_count, v_tax_count, v_comm_count;
  END IF;

  RAISE NOTICE 'Financial reset verified clean: 0 saldo, 0 ledger, 0 transactional rows';
END $$;

COMMIT;
