-- Repair queue migration: RQ-027, RQ-028, RQ-032
-- Combined DB changes from the 2026-04-07 repair queue.

-- RQ-027: Allow assigned RPs to read their discovered salons
CREATE POLICY rp_read_assigned ON discovered_salons
  FOR SELECT TO authenticated
  USING (assigned_rp_id = auth.uid());

-- RQ-028: Allow products without a photo URL
ALTER TABLE products ALTER COLUMN photo_url DROP NOT NULL;

-- RQ-032: Drop unused bitcoin tables
DROP TABLE IF EXISTS btc_deposits;
DROP TABLE IF EXISTS btc_addresses;
