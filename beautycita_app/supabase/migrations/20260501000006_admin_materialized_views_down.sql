SELECT cron.unschedule('refresh_admin_mvs') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_admin_mvs');
DROP FUNCTION IF EXISTS public.refresh_admin_materialized_views();
DROP MATERIALIZED VIEW IF EXISTS public.mv_behavioral_segment_daily;
DROP MATERIALIZED VIEW IF EXISTS public.mv_rp_attribution_daily;
DROP MATERIALIZED VIEW IF EXISTS public.mv_salon_funnel_daily;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dispute_ttr_daily;
DROP MATERIALIZED VIEW IF EXISTS public.mv_payout_breakdown_daily;
DROP MATERIALIZED VIEW IF EXISTS public.mv_revenue_daily;
