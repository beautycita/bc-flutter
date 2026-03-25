-- user_error_reports — client-side error report submissions
-- Append-only: users INSERT their own, admins READ all, no UPDATE/DELETE

CREATE TABLE IF NOT EXISTS user_error_reports (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  error_message TEXT NOT NULL,
  error_details TEXT,
  screen_name   TEXT,
  device_info   TEXT,
  app_version   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_error_reports ENABLE ROW LEVEL SECURITY;

-- Authenticated users can insert their own reports
CREATE POLICY "users_insert_own_reports" ON user_error_reports
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Admins and superadmins can read all reports
CREATE POLICY "admins_read_all_reports" ON user_error_reports
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'superadmin')
    )
  );

-- Service role has full access (for edge functions if needed)
CREATE POLICY "service_role_full_access" ON user_error_reports
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Index for admin queries
CREATE INDEX idx_error_reports_created_at ON user_error_reports (created_at DESC);
