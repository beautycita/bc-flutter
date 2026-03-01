-- Lock down time_inference_rules to admin-only access.
-- This table stores engine tuning parameters that should not be
-- readable or writable by regular users.

ALTER TABLE IF EXISTS time_inference_rules ENABLE ROW LEVEL SECURITY;

-- Drop any permissive policies that may exist
DROP POLICY IF EXISTS "Allow all access" ON time_inference_rules;
DROP POLICY IF EXISTS "Allow anon read" ON time_inference_rules;
DROP POLICY IF EXISTS "Allow authenticated read" ON time_inference_rules;

-- Only service role (used by edge functions) and admin users can read
CREATE POLICY "Admin read time_inference_rules"
  ON time_inference_rules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'superadmin')
    )
  );

-- Only admin users can insert/update/delete
CREATE POLICY "Admin write time_inference_rules"
  ON time_inference_rules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'superadmin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'superadmin')
    )
  );
