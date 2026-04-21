-- =============================================================================
-- Migration: 20260421000006_fix_list_users_role_ambiguity.sql
-- Description: Fix ambiguous "role" reference in list_users_with_traits.
-- The RETURNS TABLE declaration has a column named "role", which shadows the
-- profiles.role column in the admin check on line 8. Caught live: the RPC
-- errored "column reference \"role\" is ambiguous" for any authenticated
-- caller, making the mobile Inteligencia tab unusable.
-- =============================================================================

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
  -- Qualify with table alias to avoid collision with RETURNS TABLE column "role"
  SELECT p.role INTO v_caller_role FROM public.profiles p WHERE p.id = auth.uid();
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
      WHERE p.opted_out_analytics IS NOT TRUE
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
