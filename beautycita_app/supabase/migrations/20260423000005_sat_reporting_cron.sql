-- =============================================================================
-- SAT reporting automation — statutory day-10 deadline guard
-- =============================================================================
-- Escrito libre section IV ("24/7/365 disponibilidad") + statutory obligation
-- to file declaracion informativa by day 10 of the following month (regla
-- 2.9.21 RMF 2026). Before today sat_monthly_reports + platform_sat_declarations
-- were populated only by manual admin invocation — operational risk.
--
-- This job runs on day 9 at 03:00 UTC every month and auto-targets the prior
-- month. The sat-reporting edge function accepts X-Cron-Secret for this call.
-- On failure the job raises a NOTICE; doc's pulse cron-monitor catches it.
-- =============================================================================

-- Store the cron secret in a private table (not .env GUC which requires superuser).
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.cron_config (
  id smallint PRIMARY KEY DEFAULT 1,
  cron_secret text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 1)
);

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.cron_config FROM PUBLIC, anon, authenticated;

-- SECURITY DEFINER helper: postgres-owned function that reads the secret.
-- Granting to service_role lets the edge fn verify if ever needed; cron
-- itself runs as postgres so it can read the table directly.
CREATE OR REPLACE FUNCTION private.get_cron_secret()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = private, pg_temp
AS $$
  SELECT cron_secret FROM private.cron_config WHERE id = 1;
$$;

DO $$
DECLARE
  v_existing_jobid int;
BEGIN
  SELECT jobid INTO v_existing_jobid FROM cron.job WHERE jobname = 'sat-monthly-reporting';
  IF v_existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_jobid);
  END IF;
END$$;

SELECT cron.schedule(
  'sat-monthly-reporting',
  '0 3 9 * *',
  $$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/sat-reporting',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    ) AS request_id;
  $$
);

COMMENT ON EXTENSION pg_cron IS 'pg_cron schedules the day-9 SAT monthly reporting run so platform + per-business aggregates are generated before the statutory day-10 deadline.';
