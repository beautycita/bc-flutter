-- Down: revert tax-debt-first collection.
-- Function bodies revert by re-applying 20260425000010 (cancel_booking) +
-- 20260425000000 (create_booking_with_financials) + 20260425000002 (calculate_payout_with_debt).
-- Schema constraint reverts to the prior debt_type set.

ALTER TABLE salon_debts DROP CONSTRAINT IF EXISTS salon_debts_debt_type_check;
ALTER TABLE salon_debts ADD CONSTRAINT salon_debts_debt_type_check
  CHECK (debt_type IN (
    'operational_commission', 'operational_refund_pos',
    'operational_saldo_overdraft', 'pursued_doubtful'
  ));

DROP INDEX IF EXISTS idx_salon_debts_tax_first;

-- Function bodies are not restored here — re-apply the prior migrations.
SELECT 'noop_restore_prior_function_bodies'::text;
