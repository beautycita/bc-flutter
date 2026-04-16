-- Automatically log all role changes to audit_log
CREATE OR REPLACE FUNCTION log_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    INSERT INTO audit_log (admin_id, action, target_type, target_id, details)
    VALUES (
      COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
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

-- Drop if exists to avoid duplicate
DROP TRIGGER IF EXISTS trg_audit_role_change ON profiles;
CREATE TRIGGER trg_audit_role_change
  AFTER UPDATE OF role ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION log_role_change();
