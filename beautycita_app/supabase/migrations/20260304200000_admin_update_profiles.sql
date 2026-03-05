-- =============================================================================
-- Admin UPDATE policy on profiles
-- Date: 2026-03-04
-- Purpose: Allow admin/superadmin users to update other users' profiles
--          (role, status, etc.) from the admin panel.
-- =============================================================================

-- Admins can update any profile (role changes, status toggles, etc.)
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_update"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admins can read all profiles (needed for admin user list)
DROP POLICY IF EXISTS "profiles_admin_read" ON public.profiles;
CREATE POLICY "profiles_admin_read"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (is_admin());
