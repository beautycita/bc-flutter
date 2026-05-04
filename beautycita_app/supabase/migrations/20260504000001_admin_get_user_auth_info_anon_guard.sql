-- =============================================================================
-- 20260504000001 — admin_get_user_auth_info: close anon NULL-bypass
-- =============================================================================
-- Pre-fix the auth check was:
--   SELECT p.role INTO caller_role FROM public.profiles p WHERE p.id = auth.uid();
--   IF caller_role NOT IN ('admin', 'superadmin') THEN RAISE 'Unauthorized'; END IF;
--
-- For an anon caller, auth.uid() = NULL → the SELECT matches no row → caller_role
-- stays NULL. `NULL NOT IN (...)` evaluates to NULL under three-valued logic,
-- and `IF NULL THEN` does NOT raise. The function then returned auth.users
-- metadata (email, phone, last_sign_in, OAuth providers) for any user_id passed
-- by the caller. PII leak to anyone holding the anon key.
--
-- Caught by BC Monitor 2026-05-03 in test "Admin User & Suspension RPCs →
-- admin_get_user_auth_info: rejects anon".
--
-- Fix: route through public.is_admin(), which uses EXISTS and returns FALSE
-- for the NULL-uid case. Same authorization semantics, no NULL bypass.
-- Same migration audited 9 sister RPCs that share the anti-pattern; those
-- remain vulnerable and are queued for a systemic sweep.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_auth_info(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT jsonb_build_object(
    'email', u.email,
    'phone', COALESCE(NULLIF(u.phone, ''), prof.phone),
    'email_confirmed', u.email_confirmed_at IS NOT NULL,
    -- Truth is profiles.phone_verified_at (our WA OTP flow).
    -- Falls back to native auth flag for legacy users.
    'phone_confirmed', prof.phone_verified_at IS NOT NULL
                       OR u.phone_confirmed_at IS NOT NULL,
    'phone_verified_at', prof.phone_verified_at,
    'has_password', u.encrypted_password IS NOT NULL AND u.encrypted_password != '',
    'is_anonymous', COALESCE(u.is_anonymous, false),
    'is_sso', COALESCE(u.is_sso_user, false),
    'last_sign_in', u.last_sign_in_at,
    'created_at', u.created_at,
    'providers', COALESCE((
      SELECT jsonb_agg(DISTINCT i.provider)
      FROM auth.identities i
      WHERE i.user_id = u.id
    ), '[]'::jsonb),
    'raw_app_meta', u.raw_app_meta_data
  ) INTO result
  FROM auth.users u
  LEFT JOIN public.profiles prof ON prof.id = u.id
  WHERE u.id = p_user_id;

  RETURN COALESCE(result, '{}'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.admin_get_user_auth_info(uuid) IS
  'Returns auth metadata for a user. Admin/superadmin only. Routes through is_admin() (EXISTS) to avoid the NULL-NOT-IN bypass that allowed anon read access pre-2026-05-04.';
