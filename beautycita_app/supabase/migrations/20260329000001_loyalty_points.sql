-- Loyalty points: earn 1 point per $10 spent, redeem 100 points = $50 discount

ALTER TABLE business_clients ADD COLUMN IF NOT EXISTS loyalty_points integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  points integer NOT NULL,
  type text NOT NULL,   -- 'earned' or 'redeemed'
  source text,          -- 'appointment', 'product', 'manual', 'redemption'
  reference_id uuid,    -- appointment_id or order_id
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loyalty_tx_biz_user ON loyalty_transactions(business_id, user_id);

ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY loyalty_tx_owner ON loyalty_transactions FOR ALL USING (
  business_id IN (SELECT id FROM businesses WHERE owner_id = auth.uid())
  OR user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','superadmin'))
);

-- Auto-award loyalty points when an appointment is marked completed
CREATE OR REPLACE FUNCTION award_loyalty_points_on_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_points integer;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed')
     AND NEW.user_id IS NOT NULL AND COALESCE(NEW.price, 0) > 0 THEN
    -- 1 point per $10 spent
    v_points := FLOOR(NEW.price / 10);
    IF v_points > 0 THEN
      INSERT INTO loyalty_transactions (business_id, user_id, points, type, source, reference_id)
      VALUES (NEW.business_id, NEW.user_id, v_points, 'earned', 'appointment', NEW.id);

      UPDATE business_clients SET loyalty_points = loyalty_points + v_points, updated_at = NOW()
      WHERE business_id = NEW.business_id AND user_id = NEW.user_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_loyalty_points ON appointments;
CREATE TRIGGER trg_loyalty_points
  AFTER UPDATE ON appointments FOR EACH ROW
  EXECUTE FUNCTION award_loyalty_points_on_completion();
