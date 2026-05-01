-- Phase 0 helpers for admin redesign (decision #18, 2026-05-01).
-- Adds is_ops_admin() role helper + requires_fresh_auth() step-up gate.
-- profiles.role is text (no enum); 'ops_admin' is added by usage, no DDL.

CREATE OR REPLACE FUNCTION public.is_ops_admin()
  RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role IN ('ops_admin', 'admin', 'superadmin')
  );
$$;

-- requires_fresh_auth: returns true iff the JWT was issued within the last
-- p_max_age_seconds. Used as a step-up gate by sensitive RPCs (refund issue,
-- debt write-off, salon delete, role-change approval).
-- Reads `iat` from request.jwt.claims (Supabase populates this on every call).
CREATE OR REPLACE FUNCTION public.requires_fresh_auth(p_max_age_seconds int DEFAULT 300)
  RETURNS boolean
  LANGUAGE plpgsql STABLE
  SET search_path TO 'public'
AS $$
DECLARE
  v_iat bigint;
BEGIN
  v_iat := (current_setting('request.jwt.claims', true)::jsonb->>'iat')::bigint;
  IF v_iat IS NULL THEN
    RETURN false;
  END IF;
  RETURN (extract(epoch FROM now())::bigint - v_iat) <= p_max_age_seconds;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_ops_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.requires_fresh_auth(int) TO authenticated, service_role;

COMMENT ON FUNCTION public.is_ops_admin() IS
  'True for ops_admin, admin, superadmin. Use when surface should be visible to all admin tiers.';
COMMENT ON FUNCTION public.requires_fresh_auth(int) IS
  'Step-up auth gate. Returns true if the caller re-authenticated within p_max_age_seconds. Server-side enforcement for refund / debt write-off / salon delete / role-change approval / superadmin grant.';
