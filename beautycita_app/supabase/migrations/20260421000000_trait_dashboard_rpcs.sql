-- =============================================================================
-- Migration: 20260421000000_trait_dashboard_rpcs.sql
-- Description: RPCs powering the admin trait analytics dashboard.
-- LFPDPPP requires audit-on-read for behavioral profile data — every fetch
-- of an individual user's traits writes a row into admin_trait_access_log.
--
-- Also adds profiles.analytics_opt_out column (LFPDPPP §3 right of opposition).
-- The arco-request edge function flips this true when a user opts out;
-- list_users_with_traits excludes opted-out users so admins can't view profiles
-- of users who have refused behavioral analysis.
-- =============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS analytics_opt_out boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS profiles_analytics_opt_out_idx
  ON public.profiles(analytics_opt_out)
  WHERE analytics_opt_out = true;

COMMENT ON COLUMN public.profiles.analytics_opt_out IS
  'LFPDPPP Art. 22 right of opposition. When true, exclude user from any '
  'behavioral analytics processing (trait scoring, segmentation, dashboards). '
  'Set via arco-request type=opposition processing_type=behavioral_analytics.';

-- ---------------------------------------------------------------------------
-- get_user_trait_data: per-user fetch with atomic audit-log insert.
-- SECURITY DEFINER so the audit insert always lands even when caller's RLS
-- might not allow it; the function itself enforces admin role.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_trait_data(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_caller_id uuid;
  v_result jsonb;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;
  IF v_caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  -- LFPDPPP audit: log this view BEFORE returning data.
  -- If insert fails (FK, RLS), we abort — never return data without audit.
  INSERT INTO public.admin_trait_access_log (admin_id, viewed_user_id, context)
  VALUES (v_caller_id, p_user_id, 'view_traits');

  -- Bundle profile + traits + summary + recent events
  SELECT jsonb_build_object(
    'profile', (
      SELECT jsonb_build_object(
        'id', p.id,
        'username', p.username,
        'full_name', p.full_name,
        'role', p.role,
        'status', p.status,
        'created_at', p.created_at,
        'last_seen', p.last_seen,
        'home_city', p.home_address,
        'analytics_opt_out', p.analytics_opt_out
      )
      FROM public.profiles p WHERE p.id = p_user_id
    ),
    'trait_scores', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'trait', trait,
        'score', score,
        'raw_value', raw_value,
        'percentile', percentile,
        'computed_at', computed_at
      ) ORDER BY score DESC NULLS LAST)
      FROM public.user_trait_scores WHERE user_id = p_user_id
    ), '[]'::jsonb),
    'behavior_summary', (
      SELECT jsonb_build_object(
        'total_events', total_events,
        'first_event_at', first_event_at,
        'last_event_at', last_event_at,
        'active_days_30d', active_days_30d,
        'active_days_90d', active_days_90d,
        'primary_city', primary_city,
        'primary_state', primary_state,
        'top_event_types', top_event_types,
        'segment', segment,
        'rp_candidate_score', rp_candidate_score,
        'whale_score', whale_score,
        'churn_risk_score', churn_risk_score,
        'computed_at', computed_at
      )
      FROM public.user_behavior_summaries WHERE user_id = p_user_id
    ),
    'recent_events', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'event_type', event_type,
        'target_type', target_type,
        'target_id', target_id,
        'created_at', created_at,
        'source', source,
        'metadata', metadata
      ) ORDER BY created_at DESC)
      FROM (
        SELECT * FROM public.user_behavior_events
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 50
      ) recent
    ), '[]'::jsonb),
    'access_log_recent', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'admin_id', admin_id,
        'context', context,
        'created_at', created_at
      ) ORDER BY created_at DESC)
      FROM (
        SELECT * FROM public.admin_trait_access_log
        WHERE viewed_user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 10
      ) recent_log
    ), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_trait_data(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_user_trait_data(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_user_trait_data(uuid) IS
  'Per-user trait viewer for admin dashboard. SECURITY DEFINER. Atomically writes '
  'admin_trait_access_log row before returning data (LFPDPPP audit-on-read). '
  'Throws AUTH_REQUIRED or ADMIN_REQUIRED if caller is not admin/superadmin.';

-- ---------------------------------------------------------------------------
-- list_users_with_traits: paginated index for the dashboard list view.
-- Filter by segment (new/active/whale/churn_risk/all) + sort by score type.
-- Does NOT trigger audit log — the index view exposes only segment + scores,
-- not individual trait detail. Audit fires when admin clicks into a user.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_users_with_traits(
  p_segment text DEFAULT NULL,
  p_sort_by text DEFAULT 'rp_candidate_score',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  role text,
  segment text,
  rp_candidate_score numeric,
  whale_score numeric,
  churn_risk_score numeric,
  total_events integer,
  active_days_30d integer,
  primary_city text,
  last_event_at timestamptz,
  trait_count integer,
  total_in_segment bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;
  SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  -- Validate sort to prevent SQL-injection-style manipulation
  IF p_sort_by NOT IN ('rp_candidate_score', 'whale_score', 'churn_risk_score',
                        'total_events', 'active_days_30d', 'last_event_at') THEN
    p_sort_by := 'rp_candidate_score';
  END IF;

  RETURN QUERY EXECUTE format($q$
    WITH base AS (
      SELECT
        s.user_id,
        p.username,
        p.full_name,
        p.role,
        s.segment,
        s.rp_candidate_score,
        s.whale_score,
        s.churn_risk_score,
        s.total_events,
        s.active_days_30d,
        s.primary_city,
        s.last_event_at,
        (SELECT count(*)::int FROM user_trait_scores ts WHERE ts.user_id = s.user_id) AS trait_count
      FROM user_behavior_summaries s
      JOIN profiles p ON p.id = s.user_id
      WHERE p.analytics_opt_out IS NOT TRUE
        AND ($1 IS NULL OR s.segment = $1)
    ),
    counted AS (
      SELECT *, count(*) OVER () AS total_in_segment FROM base
    )
    SELECT * FROM counted
    ORDER BY %I DESC NULLS LAST
    LIMIT $2 OFFSET $3
  $q$, p_sort_by)
  USING p_segment, p_limit, p_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.list_users_with_traits(text, text, integer, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.list_users_with_traits(text, text, integer, integer) TO authenticated;

COMMENT ON FUNCTION public.list_users_with_traits IS
  'Paginated admin index of users with behavior summaries. SECURITY DEFINER, '
  'admin-only. Excludes users with analytics_opt_out=true (LFPDPPP). '
  'Does NOT log access — only get_user_trait_data does (per-user reveal).';

