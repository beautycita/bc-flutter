-- =============================================================================
-- Migration: 20260421000003_fix_analytics_opt_out_naming.sql
-- Description: Drop the redundant analytics_opt_out column added today by
-- 20260421000000 — it duplicates the pre-existing opted_out_analytics column
-- (added 60045 in compliance_gaps migration). The new trait dashboard RPC
-- and arco-request both filtered/wrote to the wrong column, leaving real
-- opt-outs invisible to the dashboard's exclusion logic.
--
-- Fix:
--   1. Recreate list_users_with_traits using the correct opted_out_analytics
--   2. Drop the duplicate column
--   3. arco-request will be updated in the same build
-- =============================================================================

-- Recreate the index function with correct column reference
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
      WHERE p.opted_out_analytics IS NOT TRUE     -- FIXED: was analytics_opt_out
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

-- Recreate get_user_trait_data with correct column reference (in profile bundle)
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

  INSERT INTO public.admin_trait_access_log (admin_id, viewed_user_id, context)
  VALUES (v_caller_id, p_user_id, 'view_traits');

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
        'analytics_opt_out', p.opted_out_analytics  -- FIXED: read correct column, key kept for UI
      )
      FROM public.profiles p WHERE p.id = p_user_id
    ),
    'trait_scores', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'trait', trait, 'score', score, 'raw_value', raw_value,
        'percentile', percentile, 'computed_at', computed_at
      ) ORDER BY score DESC NULLS LAST)
      FROM public.user_trait_scores WHERE user_id = p_user_id
    ), '[]'::jsonb),
    'behavior_summary', (
      SELECT jsonb_build_object(
        'total_events', total_events, 'first_event_at', first_event_at,
        'last_event_at', last_event_at, 'active_days_30d', active_days_30d,
        'active_days_90d', active_days_90d, 'primary_city', primary_city,
        'primary_state', primary_state, 'top_event_types', top_event_types,
        'segment', segment, 'rp_candidate_score', rp_candidate_score,
        'whale_score', whale_score, 'churn_risk_score', churn_risk_score,
        'computed_at', computed_at
      )
      FROM public.user_behavior_summaries WHERE user_id = p_user_id
    ),
    'recent_events', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'event_type', event_type, 'target_type', target_type,
        'target_id', target_id, 'created_at', created_at,
        'source', source, 'metadata', metadata
      ) ORDER BY created_at DESC)
      FROM (
        SELECT * FROM public.user_behavior_events
        WHERE user_id = p_user_id ORDER BY created_at DESC LIMIT 50
      ) recent
    ), '[]'::jsonb),
    'access_log_recent', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'admin_id', admin_id, 'context', context, 'created_at', created_at
      ) ORDER BY created_at DESC)
      FROM (
        SELECT * FROM public.admin_trait_access_log
        WHERE viewed_user_id = p_user_id ORDER BY created_at DESC LIMIT 10
      ) recent_log
    ), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Drop the duplicate column we accidentally created today
DROP INDEX IF EXISTS profiles_analytics_opt_out_idx;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS analytics_opt_out;
