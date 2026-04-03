-- Fix: anon cleanup was deleting real biometric-only users (no email/phone).
-- New logic: only delete TRUE orphans and abandoned stubs, never real users.

CREATE OR REPLACE FUNCTION public.cleanup_anon_users()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_deleted_ids uuid[];
  v_deleted     int;
BEGIN
  -- Collect IDs of users safe to delete:
  -- 1) Auth users with NO profile row at all (orphan from failed registration)
  -- 2) Auth users with a profile stub: username IS NULL AND older than 7 days
  --
  -- NEVER delete users who:
  -- - Have a username set (completed registration)
  -- - Have any appointments, favorites, or reviews

  SELECT array_agg(u.id) INTO v_deleted_ids
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE u.is_anonymous = true
    AND (
      -- Case 1: no profile row at all (true orphan)
      p.id IS NULL
      OR (
        -- Case 2: profile stub with no username, older than 7 days
        p.username IS NULL
        AND p.created_at < now() - interval '7 days'
      )
    )
    -- NEVER delete users with activity
    AND NOT EXISTS (SELECT 1 FROM public.appointments a WHERE a.user_id = u.id)
    AND NOT EXISTS (SELECT 1 FROM public.favorites f WHERE f.user_id = u.id)
    AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.user_id = u.id);

  -- Nothing to delete
  IF v_deleted_ids IS NULL OR array_length(v_deleted_ids, 1) IS NULL THEN
    RETURN jsonb_build_object(
      'deleted', 0,
      'reason', 'no orphans or abandoned stubs found'
    );
  END IF;

  v_deleted := array_length(v_deleted_ids, 1);

  -- Delete profiles first (FK dependency) — only for rows that exist
  DELETE FROM public.profiles
  WHERE id = ANY(v_deleted_ids);

  -- Delete from auth.users
  DELETE FROM auth.users
  WHERE id = ANY(v_deleted_ids);

  -- Audit log
  INSERT INTO public.audit_log (admin_id, action, target_type, target_id, details)
  VALUES (
    null,
    'cleanup_anon_users',
    'user',
    null,
    jsonb_build_object(
      'deleted_count', v_deleted,
      'deleted_ids', to_jsonb(v_deleted_ids)
    )
  );

  RETURN jsonb_build_object(
    'deleted', v_deleted
  );
END;
$$;

-- Only service_role can call this (cron/edge function)
REVOKE ALL ON FUNCTION public.cleanup_anon_users() FROM public, anon, authenticated;
