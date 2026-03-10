-- Auto-cleanup anonymous users when 50+ accumulate
-- Called by cron edge function every 24 hours

CREATE OR REPLACE FUNCTION public.cleanup_anon_users()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_anon_count  int;
  v_deleted_ids uuid[];
  v_deleted     int;
BEGIN
  -- Count anonymous users: no email in auth.users AND no phone in profiles
  SELECT count(*) INTO v_anon_count
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE (u.email IS NULL OR u.email = '')
    AND (u.phone IS NULL OR u.phone = '')
    AND (p.phone IS NULL OR p.phone = '')
    AND p.role = 'customer';

  -- Below threshold → skip
  IF v_anon_count < 50 THEN
    RETURN jsonb_build_object(
      'skipped', true,
      'anon_count', v_anon_count,
      'reason', 'below threshold'
    );
  END IF;

  -- Collect IDs of offline anonymous customers
  SELECT array_agg(u.id) INTO v_deleted_ids
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE (u.email IS NULL OR u.email = '')
    AND (u.phone IS NULL OR u.phone = '')
    AND (p.phone IS NULL OR p.phone = '')
    AND p.role = 'customer'
    AND (p.last_seen IS NULL OR p.last_seen < now() - interval '1 hour');

  -- Nothing to delete (all anons are currently online)
  IF v_deleted_ids IS NULL OR array_length(v_deleted_ids, 1) IS NULL THEN
    RETURN jsonb_build_object(
      'deleted', 0,
      'anon_count_before', v_anon_count,
      'reason', 'all anon users currently online'
    );
  END IF;

  v_deleted := array_length(v_deleted_ids, 1);

  -- Delete profiles first (FK dependency)
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
      'anon_count_before', v_anon_count,
      'deleted_ids', to_jsonb(v_deleted_ids)
    )
  );

  RETURN jsonb_build_object(
    'deleted', v_deleted,
    'anon_count_before', v_anon_count
  );
END;
$$;

-- Only service_role can call this (cron/edge function)
REVOKE ALL ON FUNCTION public.cleanup_anon_users() FROM public, anon, authenticated;
