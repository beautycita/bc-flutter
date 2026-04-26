-- Down: drop the columns added by 000003.
DROP INDEX IF EXISTS idx_debt_payments_source;
DROP INDEX IF EXISTS uq_debt_payments_pi;
ALTER TABLE debt_payments
  DROP COLUMN IF EXISTS stripe_payment_intent_id,
  DROP COLUMN IF EXISTS source,
  DROP COLUMN IF EXISTS amount;
-- Note: NOT NULL constraints are not restored — dropping NOT NULL is safe;
-- restoring would fail if any rows have NULL values written by 000003.
