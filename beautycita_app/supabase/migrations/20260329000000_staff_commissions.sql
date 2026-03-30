-- Staff commission rate per staff member
ALTER TABLE staff ADD COLUMN IF NOT EXISTS commission_rate numeric(5,2) DEFAULT 0;
COMMENT ON COLUMN staff.commission_rate IS 'Commission percentage (0-100) this staff member earns per completed service';

-- Commission ledger: one row per completed appointment with a rate set
CREATE TABLE IF NOT EXISTS staff_commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  appointment_id uuid REFERENCES appointments(id),
  amount numeric(10,2) NOT NULL,
  rate numeric(5,2) NOT NULL,
  service_price numeric(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staff_commissions_staff ON staff_commissions(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_commissions_biz ON staff_commissions(business_id);
ALTER TABLE staff_commissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY staff_commissions_owner ON staff_commissions FOR ALL USING (
  business_id IN (SELECT id FROM businesses WHERE owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','superadmin'))
);

-- Auto-create staff commission when appointment is completed
CREATE OR REPLACE FUNCTION create_staff_commission_on_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_rate numeric;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed')
     AND NEW.staff_id IS NOT NULL AND COALESCE(NEW.price, 0) > 0 THEN
    SELECT commission_rate INTO v_rate FROM staff WHERE id = NEW.staff_id;
    IF v_rate IS NOT NULL AND v_rate > 0 THEN
      INSERT INTO staff_commissions (staff_id, business_id, appointment_id, amount, rate, service_price)
      VALUES (NEW.staff_id, NEW.business_id, NEW.id, ROUND(NEW.price * v_rate / 100, 2), v_rate, NEW.price)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_commission ON appointments;
CREATE TRIGGER trg_staff_commission
  AFTER UPDATE ON appointments FOR EACH ROW
  EXECUTE FUNCTION create_staff_commission_on_completion();
