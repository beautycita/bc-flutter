-- Phase 2: Saldo Idempotency + Payment Atomicity (2 critical findings)
-- Saldo ledger with idempotency keys, payment status enum consolidation

-- 2.1 Saldo ledger table
CREATE TABLE IF NOT EXISTS saldo_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id),
  amount numeric(10,2) NOT NULL,
  reason text NOT NULL,
  idempotency_key text UNIQUE,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_saldo_ledger_user ON saldo_ledger(user_id);

-- Idempotent increment_saldo RPC
CREATE OR REPLACE FUNCTION increment_saldo(
  p_user_id uuid,
  p_amount numeric,
  p_reason text DEFAULT 'adjustment',
  p_idempotency_key text DEFAULT NULL
) RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_balance numeric;
BEGIN
  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM saldo_ledger WHERE idempotency_key = p_idempotency_key) THEN
      SELECT saldo INTO v_new_balance FROM profiles WHERE id = p_user_id;
      RETURN v_new_balance;
    END IF;
  END IF;
  -- Atomic update with row lock
  UPDATE profiles SET saldo = saldo + p_amount WHERE id = p_user_id
    RETURNING saldo INTO v_new_balance;
  -- Audit trail
  INSERT INTO saldo_ledger (user_id, amount, reason, idempotency_key)
    VALUES (p_user_id, p_amount, p_reason, p_idempotency_key);
  RETURN v_new_balance;
END;
$$;

-- 2.2 Consolidate payment status enum
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_payment_status_check;
ALTER TABLE appointments ADD CONSTRAINT appointments_payment_status_check
  CHECK (payment_status IN ('unpaid','pending','paid','refunded','partial_refund','failed','expired','refunded_to_saldo','deposit_forfeited'));
