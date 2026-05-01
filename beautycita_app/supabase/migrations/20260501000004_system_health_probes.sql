-- Phase 0: time-series health probes for the Operaciones → Salud timeline.
-- pg_cron writes one row per minute capturing DB latency, edge fn 5xx count,
-- backup freshness, Stripe success rate. Auditoría chart reads this table
-- directly (last N hours, downsample as needed for the timeline).

CREATE TABLE IF NOT EXISTS public.system_health_probes (
  id bigserial PRIMARY KEY,
  probed_at timestamptz NOT NULL DEFAULT now(),
  db_latency_ms numeric(8,2),                    -- self-ping latency
  edge_fn_5xx_last_5min int,                     -- count from audit_log? unused for now (NULL until we have an edge-fn error log)
  active_connections int,                        -- pg_stat_activity count
  cron_jobs_failing int,                         -- pg_cron jobs with last_run failed
  backup_age_hours int,                          -- hours since last successful backup
  stripe_charges_24h_success_pct numeric(5,2),   -- last-24h Stripe charge success rate
  stripe_payouts_24h_success_pct numeric(5,2),
  wa_service_up boolean,                         -- WA biz API responding
  notes text                                     -- freeform diagnostics for the latest probe
);

CREATE INDEX IF NOT EXISTS idx_system_health_probes_probed_at
  ON public.system_health_probes(probed_at DESC);

-- Cap retention at 60 days; the timeline shows last 7 days max in the UI.
CREATE INDEX IF NOT EXISTS idx_system_health_probes_old
  ON public.system_health_probes(probed_at)
  WHERE probed_at < now() - interval '60 days';

ALTER TABLE public.system_health_probes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "system_health_probes_admin_read" ON public.system_health_probes;
CREATE POLICY "system_health_probes_admin_read" ON public.system_health_probes
  FOR SELECT USING (public.is_ops_admin());

-- Probe writer RPC. Called every minute by pg_cron. Self-contained: no
-- external HTTP calls (those would block the scheduler). It samples what
-- it can from the DB itself; richer probes (Stripe API, WA endpoint) are
-- written by the edge-fn cron instead.
CREATE OR REPLACE FUNCTION public.write_system_health_probe()
  RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_db_latency numeric;
  v_active_conns int;
  v_cron_failing int;
  v_charge_success numeric;
  v_payout_success numeric;
  v_t0 timestamp;
BEGIN
  v_t0 := clock_timestamp();
  PERFORM 1;
  v_db_latency := extract(milliseconds FROM (clock_timestamp() - v_t0));

  SELECT count(*) INTO v_active_conns FROM pg_stat_activity WHERE state = 'active';

  -- pg_cron jobs that failed on their last run
  BEGIN
    SELECT count(DISTINCT jobid) INTO v_cron_failing
    FROM cron.job_run_details
    WHERE end_time > now() - interval '1 hour'
      AND status = 'failed';
  EXCEPTION WHEN OTHERS THEN
    v_cron_failing := NULL;
  END;

  -- Stripe charge success rate (last 24h)
  BEGIN
    SELECT ROUND(100.0 * count(*) FILTER (WHERE status = 'succeeded') / NULLIF(count(*), 0), 2)
      INTO v_charge_success
    FROM public.payment_intents
    WHERE created_at > now() - interval '24 hours';
  EXCEPTION WHEN OTHERS THEN
    v_charge_success := NULL;
  END;

  -- Payouts: best-effort; assumes a payouts table or commission_records
  v_payout_success := NULL; -- wired in Phase 3 when we have a unified payouts surface

  INSERT INTO public.system_health_probes
    (db_latency_ms, active_connections, cron_jobs_failing,
     stripe_charges_24h_success_pct, stripe_payouts_24h_success_pct)
  VALUES
    (v_db_latency, v_active_conns, v_cron_failing,
     v_charge_success, v_payout_success);
END;
$$;

GRANT EXECUTE ON FUNCTION public.write_system_health_probe() TO postgres, service_role;

-- Schedule: every minute. Idempotent — drops + recreates.
SELECT cron.unschedule('system_health_probe') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'system_health_probe');
SELECT cron.schedule(
  'system_health_probe',
  '* * * * *',
  $$SELECT public.write_system_health_probe();$$
);

-- Also schedule a 60-day pruner (daily at 04:00)
SELECT cron.unschedule('system_health_probe_prune') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'system_health_probe_prune');
SELECT cron.schedule(
  'system_health_probe_prune',
  '0 4 * * *',
  $$DELETE FROM public.system_health_probes WHERE probed_at < now() - interval '60 days';$$
);
