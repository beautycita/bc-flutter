-- =============================================================================
-- Extend debt_payments to support manual Stripe payment ("Pagar ahora")
-- =============================================================================
-- The existing debt_payments table is shaped for payout-collection flows
-- (amount_deducted + payout_amount + original_payout). For salon-initiated
-- Stripe payments toward tax_obligation debt, those columns are not natural;
-- add a generic `amount` column + source/PI columns and relax NOT NULLs.
-- =============================================================================

ALTER TABLE debt_payments
  ADD COLUMN IF NOT EXISTS amount                   numeric(10,2),
  ADD COLUMN IF NOT EXISTS source                   text NOT NULL DEFAULT 'payout_collection',
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id text;

ALTER TABLE debt_payments
  ALTER COLUMN amount_deducted DROP NOT NULL,
  ALTER COLUMN payout_amount   DROP NOT NULL,
  ALTER COLUMN original_payout DROP NOT NULL,
  ALTER COLUMN business_id     DROP NOT NULL;

DROP INDEX IF EXISTS uq_debt_payments_pi;
CREATE UNIQUE INDEX uq_debt_payments_pi
  ON debt_payments (stripe_payment_intent_id, debt_id)
  WHERE stripe_payment_intent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_debt_payments_source
  ON debt_payments (source, created_at DESC);

COMMENT ON COLUMN debt_payments.amount IS
  'Generic amount applied to the linked salon_debts row. For Pagar ahora flow this is the amount applied to tax_obligation; for payout collections amount_deducted is used.';
COMMENT ON COLUMN debt_payments.source IS
  'payout_collection (calculate_payout_with_debt) | stripe_pagar_ahora (manual Stripe debit/oxxo).';
