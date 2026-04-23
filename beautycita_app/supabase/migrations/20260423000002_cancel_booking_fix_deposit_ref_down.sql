-- Rollback: revert cancel_booking to the 20260420000000 body (buggy s.deposit_amount)
-- so you can re-apply the forward migration without stacking replacements.
-- Kept for procedural completeness; in practice you'd never roll back to a broken version.
\i 20260420000000_saldo_idempotency_callers.sql
