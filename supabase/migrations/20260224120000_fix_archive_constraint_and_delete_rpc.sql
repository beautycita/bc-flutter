-- Fix: Drop conflicting old constraint that blocks 'archived' status.
-- chk_profiles_status only allowed ('active','suspended','blocked','pending_approval')
-- but profiles_status_check correctly allows ('active','suspended','archived').
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_profiles_status;

-- RPC for admin to permanently delete a user (cascades from auth.users to profiles).
CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated;
