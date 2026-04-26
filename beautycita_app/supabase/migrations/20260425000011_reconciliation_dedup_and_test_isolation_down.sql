-- Down: revert dedup + is_test invariant patches.
-- Data cleanup (cleared salon_debts, deleted phantom saldo_ledger) is not
-- restored — the deleted rows were phantoms of fixture activity.

DROP FUNCTION IF EXISTS should_alert_reconciliation(text, text, int);
DROP TABLE IF EXISTS reconciliation_alert_state CASCADE;

-- Restoring the prior bodies is out of scope; running this down requires
-- re-applying 20260420000001_reconciliation_watchdog.sql.
