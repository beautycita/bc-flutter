-- Fix #177: Revoke authenticated access to batch RPCs (DoS vector)
REVOKE EXECUTE ON FUNCTION compute_all_user_traits() FROM authenticated;
REVOKE EXECUTE ON FUNCTION evaluate_behavior_triggers() FROM authenticated;
-- Keep compute_user_traits(uuid) for authenticated but add admin check inside
-- Actually revoke it too — admin panel uses service_role key
REVOKE EXECUTE ON FUNCTION compute_user_traits(uuid) FROM authenticated;

-- Fix #178: Audit trigger — use NULL instead of sentinel UUID
CREATE OR REPLACE FUNCTION log_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    INSERT INTO audit_log (admin_id, action, target_type, target_id, details)
    VALUES (
      auth.uid(),  -- NULL for system changes, which is fine (column is nullable)
      'role_change',
      'profile',
      NEW.id::text,
      jsonb_build_object(
        'old_role', OLD.role,
        'new_role', NEW.role,
        'changed_by', COALESCE(auth.uid()::text, 'system'),
        'username', NEW.username
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Fix #179: Add opted_out_analytics_at column for precise retention timing
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS opted_out_analytics_at timestamptz;

-- Update cleanup function to use the new timestamp column
CREATE OR REPLACE FUNCTION cleanup_opted_out_traits()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int := 0;
BEGIN
  WITH opted_out AS (
    SELECT id FROM profiles
    WHERE opted_out_analytics = true
      AND opted_out_analytics_at IS NOT NULL
      AND opted_out_analytics_at < now() - interval '30 days'
  )
  DELETE FROM user_trait_scores
  WHERE user_id IN (SELECT id FROM opted_out);
  GET DIAGNOSTICS v_count = ROW_COUNT;

  DELETE FROM user_behavior_summaries
  WHERE user_id IN (
    SELECT id FROM profiles
    WHERE opted_out_analytics = true
      AND opted_out_analytics_at IS NOT NULL
      AND opted_out_analytics_at < now() - interval '30 days'
  );

  RETURN v_count;
END;
$$;
