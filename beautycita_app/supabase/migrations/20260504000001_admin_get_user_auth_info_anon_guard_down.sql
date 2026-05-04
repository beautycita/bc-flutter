-- Reverts to the pre-2026-05-04 form. Restores the NULL-bypass — for
-- audit/replay only, do not run on production.

CREATE OR REPLACE FUNCTION public.admin_get_user_auth_info(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  caller_role text;
BEGIN
  SELECT p.role INTO caller_role FROM public.profiles p WHERE p.id = auth.uid();
  IF caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT jsonb_build_object(
    'email', u.email,
    'phone', COALESCE(NULLIF(u.phone, ''), prof.phone),
    'email_confirmed', u.email_confirmed_at IS NOT NULL,
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
