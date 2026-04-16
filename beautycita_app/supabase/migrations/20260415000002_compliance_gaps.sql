-- Close 3 compliance gaps: ARCO access, data retention, admin audit trail

-- ============================================================
-- 1. ARCO Access: get_my_traits RPC (Measure 4)
-- Users can request their own trait profile
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_traits()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_traits jsonb;
  v_summary jsonb;
  v_events_count int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get all trait scores
  SELECT COALESCE(jsonb_object_agg(trait, jsonb_build_object(
    'score', score,
    'raw_value', raw_value,
    'computed_at', computed_at
  )), '{}'::jsonb)
  INTO v_traits
  FROM user_trait_scores
  WHERE user_id = v_uid;

  -- Get behavior summary
  SELECT to_jsonb(s) - 'user_id'
  INTO v_summary
  FROM user_behavior_summaries s
  WHERE user_id = v_uid;

  -- Count total events
  SELECT count(*)
  INTO v_events_count
  FROM user_behavior_events
  WHERE user_id = v_uid;

  RETURN jsonb_build_object(
    'user_id', v_uid,
    'traits', v_traits,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'total_events', v_events_count,
    'requested_at', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_traits() TO authenticated;

-- ============================================================
-- 2. Admin Trait Access Logging (Measure 9)
-- Log when admins view individual user trait profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_trait_access_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES profiles(id),
  viewed_user_id uuid NOT NULL REFERENCES profiles(id),
  context text DEFAULT 'view_traits',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_atal_admin ON admin_trait_access_log (admin_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_atal_viewed ON admin_trait_access_log (viewed_user_id, created_at DESC);

ALTER TABLE admin_trait_access_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY atal_service ON admin_trait_access_log
  FOR ALL TO service_role USING (true);

CREATE POLICY atal_admin_insert ON admin_trait_access_log
  FOR INSERT TO authenticated
  WITH CHECK (admin_id = auth.uid());

CREATE POLICY atal_admin_read ON admin_trait_access_log
  FOR SELECT TO authenticated
  USING (admin_id = auth.uid());

-- RPC for admin to log access + fetch traits in one call
CREATE OR REPLACE FUNCTION admin_view_user_traits(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin uuid := auth.uid();
  v_admin_role text;
  v_traits jsonb;
  v_summary jsonb;
  v_profile jsonb;
BEGIN
  -- Verify caller is admin
  SELECT role INTO v_admin_role FROM profiles WHERE id = v_admin;
  IF v_admin_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  -- Log the access
  INSERT INTO admin_trait_access_log (admin_id, viewed_user_id, context)
  VALUES (v_admin, p_user_id, 'admin_dashboard_view');

  -- Return traits
  SELECT COALESCE(jsonb_object_agg(trait, jsonb_build_object(
    'score', score, 'raw_value', raw_value, 'computed_at', computed_at
  )), '{}'::jsonb)
  INTO v_traits
  FROM user_trait_scores WHERE user_id = p_user_id;

  SELECT to_jsonb(s) - 'user_id' INTO v_summary
  FROM user_behavior_summaries s WHERE user_id = p_user_id;

  SELECT jsonb_build_object('username', username, 'full_name', full_name, 'role', role)
  INTO v_profile FROM profiles WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'profile', COALESCE(v_profile, '{}'::jsonb),
    'traits', v_traits,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'accessed_by', v_admin,
    'accessed_at', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_view_user_traits(uuid) TO authenticated;

-- ============================================================
-- 3. Data Retention: cleanup functions (Measure 6)
-- ============================================================

-- 3a. Delete trait scores 30 days after opt-out
CREATE OR REPLACE FUNCTION cleanup_opted_out_traits()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int := 0;
BEGIN
  -- Find users who opted out more than 30 days ago
  -- Delete their trait scores and behavior summaries
  WITH opted_out AS (
    SELECT id FROM profiles
    WHERE opted_out_analytics = true
      AND updated_at < now() - interval '30 days'
  )
  DELETE FROM user_trait_scores
  WHERE user_id IN (SELECT id FROM opted_out);
  GET DIAGNOSTICS v_count = ROW_COUNT;

  DELETE FROM user_behavior_summaries
  WHERE user_id IN (
    SELECT id FROM profiles
    WHERE opted_out_analytics = true
      AND updated_at < now() - interval '30 days'
  );

  RETURN v_count;
END;
$$;

-- 3b. Archive old behavioral events (>24 months)
-- This just deletes them — R2 archive should be done via backup script first
CREATE OR REPLACE FUNCTION cleanup_old_behavior_events()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int;
BEGIN
  DELETE FROM user_behavior_events
  WHERE created_at < now() - interval '24 months';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 3c. Cleanup summaries for deleted accounts (>12 months after deletion)
-- Profiles are cascade-deleted, so summaries should already be gone via FK
-- This catches any orphans
CREATE OR REPLACE FUNCTION cleanup_orphaned_summaries()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int;
BEGIN
  DELETE FROM user_behavior_summaries
  WHERE user_id NOT IN (SELECT id FROM profiles);
  GET DIAGNOSTICS v_count = ROW_COUNT;

  DELETE FROM user_trait_scores
  WHERE user_id NOT IN (SELECT id FROM profiles);

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION cleanup_opted_out_traits() TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_old_behavior_events() TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_orphaned_summaries() TO service_role;

-- ============================================================
-- 4. Schedule retention crons (if pg_cron available)
-- ============================================================
-- These may fail if pg_cron is not installed — that's OK, they can be run manually
DO $$
BEGIN
  -- Daily at 5am: clean opted-out traits
  PERFORM cron.schedule('cleanup_opted_out_traits', '0 5 * * *',
    'SELECT cleanup_opted_out_traits()');
  -- Weekly Sunday 4am: archive old events
  PERFORM cron.schedule('cleanup_old_behavior_events', '0 4 * * 0',
    'SELECT cleanup_old_behavior_events()');
  -- Weekly Sunday 4:30am: clean orphaned summaries
  PERFORM cron.schedule('cleanup_orphaned_summaries', '30 4 * * 0',
    'SELECT cleanup_orphaned_summaries()');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available — retention functions must be called manually or via edge function cron';
END;
$$;
