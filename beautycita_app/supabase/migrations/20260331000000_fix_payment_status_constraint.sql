-- Fix payment_status CHECK constraint to include deposit_forfeited and refund_pending
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_payment_status_check;
ALTER TABLE appointments ADD CONSTRAINT appointments_payment_status_check
  CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'refunded', 'partial_refund', 'failed', 'refunded_to_saldo', 'deposit_forfeited', 'refund_pending'));
