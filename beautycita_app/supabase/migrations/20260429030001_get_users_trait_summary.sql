-- Bulk trait fetch for the admin intel browser, with one audit-log row per
-- list view (instead of bypassing audit entirely as the prior direct
-- user_trait_scores select did).

CREATE OR REPLACE FUNCTION public.get_users_trait_summary(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  trait text,
  score numeric,
  raw_value numeric,
  percentile numeric,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_role text;
  v_uid uuid;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;
  IF v_caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  IF array_length(p_user_ids, 1) > 500 THEN
    RAISE EXCEPTION 'BATCH_TOO_LARGE' USING ERRCODE = '22023';
  END IF;

  -- One audit-log row per user in the batch so the access trail is per-subject
  -- (an admin can't read 500 users' traits with only one log row).
  FOREACH v_uid IN ARRAY p_user_ids LOOP
    INSERT INTO public.admin_trait_access_log (admin_id, viewed_user_id, context)
    VALUES (v_caller_id, v_uid, 'bulk_view_traits');
  END LOOP;

  RETURN QUERY
  SELECT t.user_id, t.trait, t.score, t.raw_value, t.percentile, t.computed_at
  FROM public.user_trait_scores t
  WHERE t.user_id = ANY(p_user_ids);
END;
$$;

REVOKE ALL ON FUNCTION public.get_users_trait_summary(uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION public.get_users_trait_summary(uuid[]) TO authenticated;

COMMENT ON FUNCTION public.get_users_trait_summary(uuid[]) IS
  'Bulk trait scores for the admin intel browser. Writes one admin_trait_access_log row per user in the batch (LFPDPPP audit). Capped at 500 users per call.';
