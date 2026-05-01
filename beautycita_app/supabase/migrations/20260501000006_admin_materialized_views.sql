-- Phase 0: 6 materialized views feeding the chart fleet (15-min pg_cron refresh).
-- Refreshing concurrently keeps the views queryable during refresh.

-- ─── mv_revenue_daily ─────────────────────────────────────────────────────
-- Daily revenue split by source (booking vs POS) for the 90-day trend chart.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_revenue_daily AS
WITH bookings AS (
  SELECT date_trunc('day', a.starts_at)::date AS day,
         'booking'::text AS source,
         COALESCE(sum(a.price), 0)::numeric AS gross,
         count(*)::int AS txn_count
  FROM public.appointments a
  WHERE a.status IN ('confirmed', 'completed')
    AND a.starts_at >= now() - interval '90 days'
  GROUP BY 1
),
pos AS (
  SELECT date_trunc('day', o.created_at)::date AS day,
         'pos'::text AS source,
         COALESCE(sum(o.total_amount), 0)::numeric AS gross,
         count(*)::int AS txn_count
  FROM public.orders o
  WHERE o.status NOT IN ('cancelled', 'refunded')
    AND o.created_at >= now() - interval '90 days'
  GROUP BY 1
)
SELECT day, source, gross, txn_count FROM bookings
UNION ALL
SELECT day, source, gross, txn_count FROM pos;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_revenue_daily_pk
  ON public.mv_revenue_daily(day, source);

-- ─── mv_payout_breakdown_daily ────────────────────────────────────────────
-- Revenue → commission → withholdings → debt-applied → net payout, by day.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_payout_breakdown_daily AS
SELECT
  date_trunc('day', a.starts_at)::date AS day,
  COALESCE(sum(a.price), 0)::numeric AS gross_revenue,
  COALESCE(sum(cr.amount), 0)::numeric AS commission_total,
  COALESCE(sum(tw.isr_withheld), 0)::numeric AS isr_to_sat,
  COALESCE(sum(tw.iva_withheld), 0)::numeric AS iva_to_sat,
  COALESCE(sum(a.price)
    - sum(cr.amount)
    - sum(tw.isr_withheld)
    - sum(tw.iva_withheld), 0)::numeric AS net_payable_to_salons
FROM public.appointments a
LEFT JOIN public.commission_records cr ON cr.appointment_id = a.id
LEFT JOIN public.tax_withholdings tw ON tw.appointment_id = a.id AND COALESCE(tw.status, 'active') = 'active'
WHERE a.status IN ('confirmed', 'completed')
  AND a.starts_at >= now() - interval '90 days'
GROUP BY 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_payout_breakdown_daily_pk
  ON public.mv_payout_breakdown_daily(day);

-- ─── mv_dispute_ttr_daily ─────────────────────────────────────────────────
-- Median time-to-resolve per day, last 30d. Resolved = status terminal.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_dispute_ttr_daily AS
SELECT
  date_trunc('day', d.created_at)::date AS day,
  count(*)::int AS opened,
  count(*) FILTER (WHERE d.status IN ('resolved', 'denied'))::int AS resolved,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY
    EXTRACT(EPOCH FROM (
      COALESCE(d.updated_at, now()) - d.created_at
    ))
  ) FILTER (WHERE d.status IN ('resolved', 'denied'))::numeric AS median_ttr_seconds
FROM public.disputes d
WHERE d.created_at >= now() - interval '30 days'
GROUP BY 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dispute_ttr_daily_pk
  ON public.mv_dispute_ttr_daily(day);

-- ─── mv_salon_funnel_daily ────────────────────────────────────────────────
-- Salon onboarding funnel snapshot per day: discovered → registered →
-- onboarding_complete → has_charges (Stripe-ready). Cumulative state.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_salon_funnel_daily AS
SELECT
  current_date AS as_of,
  (SELECT count(*) FROM public.discovered_salons)::int                                    AS discovered_total,
  (SELECT count(*) FROM public.discovered_salons WHERE assigned_rp_id IS NOT NULL)::int  AS rp_assigned,
  (SELECT count(*) FROM public.businesses)::int                                            AS registered_total,
  (SELECT count(*) FROM public.businesses WHERE onboarding_complete)::int                 AS onboarded_total,
  (SELECT count(*) FROM public.businesses WHERE stripe_charges_enabled)::int              AS payout_ready_total,
  (SELECT count(*) FROM public.businesses WHERE rfc IS NOT NULL AND rfc <> '')::int       AS rfc_complete_total;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_salon_funnel_daily_pk
  ON public.mv_salon_funnel_daily(as_of);

-- ─── mv_rp_attribution_daily ──────────────────────────────────────────────
-- Per-RP: leads assigned, leads converted (status=interested+), revenue
-- attributed (sum of commission_records on businesses owned by users that
-- registered after the RP touched the discovered_salon).
-- Simpler v1: leads assigned + converted; revenue attribution wired in
-- Phase 3 once we have a stable lineage table.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_rp_attribution_daily AS
SELECT
  ds.assigned_rp_id AS rp_id,
  count(*)::int AS leads_assigned,
  count(*) FILTER (WHERE ds.status IN ('interested', 'converted', 'onboarded'))::int AS leads_warm,
  count(*) FILTER (WHERE ds.status = 'converted' OR ds.status = 'onboarded')::int AS leads_converted,
  current_date AS as_of
FROM public.discovered_salons ds
WHERE ds.assigned_rp_id IS NOT NULL
GROUP BY ds.assigned_rp_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rp_attribution_daily_pk
  ON public.mv_rp_attribution_daily(rp_id, as_of);

-- ─── mv_behavioral_segment_daily ──────────────────────────────────────────
-- Daily snapshot of segment sizes from user_trait_scores. Skipped if the
-- table doesn't exist yet (returns empty).
-- user_trait_scores is long-form: (user_id, trait, score, ...). One row per
-- trait per user. The segment view counts distinct users above per-trait
-- thresholds.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'user_trait_scores') THEN
    EXECUTE $mv$
      CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_behavioral_segment_daily AS
      SELECT
        current_date AS as_of,
        (SELECT count(DISTINCT user_id) FROM public.user_trait_scores WHERE trait = 'rp_candidate_score' AND score >= 50)::int AS rp_candidates,
        (SELECT count(DISTINCT user_id) FROM public.user_trait_scores WHERE trait = 'whale_score' AND score >= 70)::int          AS whales,
        (SELECT count(DISTINCT user_id) FROM public.user_trait_scores WHERE trait = 'churn_risk_score' AND score >= 60)::int    AS churn_risk,
        (SELECT count(DISTINCT user_id) FROM public.user_trait_scores WHERE computed_at > now() - interval '7 days')::int       AS active_7d
    $mv$;
    EXECUTE $mv$ CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_behavioral_segment_daily_pk ON public.mv_behavioral_segment_daily(as_of) $mv$;
  END IF;
END $$;

-- ─── pg_cron refresh schedule (15 min) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.refresh_admin_materialized_views()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_revenue_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_payout_breakdown_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_dispute_ttr_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_salon_funnel_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_rp_attribution_daily;
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_behavioral_segment_daily') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_behavioral_segment_daily;
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Don't break the cron; log to audit_log_failures if it exists
  BEGIN
    INSERT INTO public.audit_log_failures (attempted_payload, error_text)
    VALUES (jsonb_build_object('cron', 'refresh_admin_materialized_views'), SQLERRM);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_admin_materialized_views() TO postgres, service_role;

SELECT cron.unschedule('refresh_admin_mvs') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_admin_mvs');
SELECT cron.schedule(
  'refresh_admin_mvs',
  '*/15 * * * *',
  $$SELECT public.refresh_admin_materialized_views();$$
);

-- Grant SELECT on views to authenticated (RLS would be ideal but matviews
-- don't support row-level policies; access is gated by the consuming RPC).
GRANT SELECT ON public.mv_revenue_daily TO authenticated;
GRANT SELECT ON public.mv_payout_breakdown_daily TO authenticated;
GRANT SELECT ON public.mv_dispute_ttr_daily TO authenticated;
GRANT SELECT ON public.mv_salon_funnel_daily TO authenticated;
GRANT SELECT ON public.mv_rp_attribution_daily TO authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_behavioral_segment_daily') THEN
    EXECUTE $g$GRANT SELECT ON public.mv_behavioral_segment_daily TO authenticated$g$;
  END IF;
END $$;

-- Initial population (so charts have data on first load)
REFRESH MATERIALIZED VIEW public.mv_revenue_daily;
REFRESH MATERIALIZED VIEW public.mv_payout_breakdown_daily;
REFRESH MATERIALIZED VIEW public.mv_dispute_ttr_daily;
REFRESH MATERIALIZED VIEW public.mv_salon_funnel_daily;
REFRESH MATERIALIZED VIEW public.mv_rp_attribution_daily;
