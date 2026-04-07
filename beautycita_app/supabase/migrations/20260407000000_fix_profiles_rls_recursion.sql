-- =============================================================================
-- Fix infinite recursion (42P17) on profiles table
--
-- Root cause: "Admin: full access to profiles" policy uses an inline
-- EXISTS(SELECT FROM profiles) which triggers RLS on the same table,
-- creating infinite recursion.
--
-- Fix: Replace inline query with is_admin() which is SECURITY DEFINER
-- and bypasses RLS.
-- =============================================================================

DROP POLICY IF EXISTS "Admin: full access to profiles" ON public.profiles;
CREATE POLICY "Admin: full access to profiles"
  ON public.profiles FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
