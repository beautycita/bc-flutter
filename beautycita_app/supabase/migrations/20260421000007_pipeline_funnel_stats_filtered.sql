-- =============================================================================
-- Migration: 20260421000007_pipeline_funnel_stats_filtered.sql
-- Description: Server-side filter-aware pipeline funnel stats.
-- The mobile admin pipeline header shows Total / Contactados / Registrados /
-- Conversion. Before this, those counts ignored the active filter chain
-- (country, state, city, source, has_whatsapp, assigned_rp, etc.) so selecting
-- MX still showed the global 106k Total. BC flagged this repeatedly.
--
-- This RPC mirrors the scalar filter predicates of search_discovered_salons
-- but counts by status. Geo-radius filtering is included via location column
-- (PostGIS) to keep parity with the search RPC.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pipeline_funnel_stats_filtered(
  p_query text DEFAULT '',
  p_city_filter text DEFAULT NULL,
  p_country_filter text DEFAULT NULL,
  p_state_filter text DEFAULT NULL,
  p_has_whatsapp boolean DEFAULT NULL,
  p_has_interest boolean DEFAULT NULL,
  p_source_filter text DEFAULT NULL,
  p_assigned_rp_id uuid DEFAULT NULL,
  p_rp_status_filter text DEFAULT NULL,
  p_pin_lat double precision DEFAULT NULL,
  p_pin_lng double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_counts jsonb;
  v_has_geo boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;
  SELECT p.role INTO v_caller_role FROM public.profiles p WHERE p.id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'superadmin', 'rp') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  v_has_geo := p_pin_lat IS NOT NULL AND p_pin_lng IS NOT NULL AND p_radius_km IS NOT NULL;

  SELECT jsonb_object_agg(status, cnt) INTO v_counts
  FROM (
    SELECT d.status, count(*)::int AS cnt
    FROM public.discovered_salons d
    WHERE d.status IN ('discovered','selected','outreach_sent','registered','declined','unreachable')
      AND (p_query = '' OR d.business_name ILIKE '%' || p_query || '%')
      AND (p_city_filter IS NULL OR d.location_city ILIKE '%' || p_city_filter || '%')
      AND (p_country_filter IS NULL OR lower(d.country) = lower(p_country_filter))
      AND (p_state_filter IS NULL OR lower(d.location_state) = lower(p_state_filter))
      AND (
        p_has_whatsapp IS NULL
        OR (p_has_whatsapp = TRUE AND d.whatsapp IS NOT NULL AND d.whatsapp <> '')
        OR (p_has_whatsapp = FALSE AND (d.whatsapp IS NULL OR d.whatsapp = ''))
      )
      AND (
        p_has_interest IS NULL
        OR (p_has_interest = TRUE AND d.interest_count > 0)
        OR (p_has_interest = FALSE AND d.interest_count = 0)
      )
      AND (p_source_filter IS NULL OR d.source = p_source_filter)
      AND (p_assigned_rp_id IS NULL OR d.assigned_rp_id = p_assigned_rp_id)
      AND (p_rp_status_filter IS NULL OR d.rp_status = p_rp_status_filter)
      AND (
        NOT v_has_geo
        OR (
          d.location IS NOT NULL
          AND ST_DWithin(
            d.location::geography,
            ST_SetSRID(ST_MakePoint(p_pin_lng, p_pin_lat), 4326)::geography,
            p_radius_km * 1000
          )
        )
      )
    GROUP BY d.status
  ) t;

  RETURN COALESCE(v_counts, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.pipeline_funnel_stats_filtered(text,text,text,text,boolean,boolean,text,uuid,text,double precision,double precision,double precision) FROM public;
GRANT EXECUTE ON FUNCTION public.pipeline_funnel_stats_filtered(text,text,text,text,boolean,boolean,text,uuid,text,double precision,double precision,double precision) TO authenticated;

COMMENT ON FUNCTION public.pipeline_funnel_stats_filtered IS
  'Filter-aware pipeline funnel counts. Mirrors search_discovered_salons scalar '
  'predicates and counts by status. Returns jsonb {status: count, ...}. '
  'Admin/superadmin/rp only.';
