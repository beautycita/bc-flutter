-- =============================================================================
-- Deep audit fixes: unique constraints, RLS, missing toggles, status constraints
-- Addresses findings #2, #15, #16, #23, #26, #33, #34 from deep audit
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Staff commissions: add unique constraint to prevent double-pay (#15)
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_commissions_unique_appointment
  ON staff_commissions(appointment_id) WHERE appointment_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Loyalty transactions: add unique constraint to prevent double-award (#16)
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_loyalty_transactions_unique_ref
  ON loyalty_transactions(business_id, user_id, reference_id)
  WHERE reference_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. Double-booking prevention: unique constraint on staff+time (#26)
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_appointments_no_double_book
  ON appointments(staff_id, starts_at)
  WHERE staff_id IS NOT NULL
    AND status NOT IN ('cancelled_customer', 'cancelled_business', 'no_show');

-- ---------------------------------------------------------------------------
-- 4. RLS on automated_message_log (#33)
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS automated_message_log ENABLE ROW LEVEL SECURITY;

-- Business owners can read their own logs
DO $$ BEGIN
  CREATE POLICY "automated_message_log: business owner read"
    ON automated_message_log FOR SELECT
    TO authenticated
    USING (
      EXISTS (SELECT 1 FROM businesses WHERE id = automated_message_log.business_id AND owner_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Service role full access
DO $$ BEGIN
  CREATE POLICY "automated_message_log: service_role all"
    ON automated_message_log FOR ALL
    TO service_role
    USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 5. Fix user_error_reports RLS — restrict SELECT to own reports + admin (#34)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "user_error_reports: users read own"
    ON user_error_reports FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 6. Non-RFC salon tax rates — add rate lookup to app_config (#2)
-- ---------------------------------------------------------------------------
INSERT INTO app_config (key, value, data_type, group_name, description_es)
VALUES
  ('isr_rate_no_rfc', '0.20', 'number', 'tax', 'Tasa ISR para prestadores SIN RFC (20%)'),
  ('iva_rate_no_rfc', '0.16', 'number', 'tax', 'Tasa IVA para prestadores SIN RFC (16% completo)')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. SAT reporting: fix superadmin lockout (#23)
-- Update any policies that check role = 'admin' to also include 'superadmin'
-- (Already fixed in 20260405100000 for most tables, but verify sat_monthly_reports)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "sat_monthly_reports: admin only" ON sat_monthly_reports;
  CREATE POLICY "sat_monthly_reports: admin and superadmin"
    ON sat_monthly_reports FOR ALL
    TO authenticated
    USING (is_admin());
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 8. Payments table: add status constraint to match webhook values (#12)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check;
  ALTER TABLE payments ADD CONSTRAINT payments_status_check
    CHECK (status IN ('pending', 'completed', 'succeeded', 'refunded', 'failed'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 9. enable_instant_booking (already inserted on prod, adding to migration) (#7)
-- ---------------------------------------------------------------------------
INSERT INTO app_config (key, value, data_type, group_name, description_es)
VALUES ('enable_instant_booking', 'true', 'bool', 'booking', 'Habilita el motor de reservas instantaneas')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 10. No-show processing: dedicated toggle so push notification toggle
--     doesn't accidentally block no-show processing (#23 audit finding)
-- ---------------------------------------------------------------------------
INSERT INTO app_config (key, value, data_type, group_name, description_es)
VALUES ('enable_no_show_processing', 'true', 'bool', 'booking', 'Habilitar procesamiento de no-shows (reembolso parcial + deposito)')
ON CONFLICT (key) DO NOTHING;
