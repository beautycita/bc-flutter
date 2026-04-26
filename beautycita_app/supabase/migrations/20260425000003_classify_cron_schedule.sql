-- =============================================================================
-- pg_cron schedule for the HVT classifier
-- =============================================================================
-- Auth via private.cron_config + X-Cron-Secret header (no inline JWT/bearer).
-- Idempotent: unschedule any prior copy by name, then re-schedule.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE IF NOT EXISTS private.cron_config (
  id smallint PRIMARY KEY DEFAULT 1,
  cron_secret text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 1)
);
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.cron_config FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.get_cron_secret()
RETURNS text LANGUAGE sql SECURITY DEFINER
SET search_path = private, pg_temp
AS $$
  SELECT cron_secret FROM private.cron_config WHERE id = 1;
$$;

DO $$
DECLARE
  v_existing_jobid int;
BEGIN
  SELECT jobid INTO v_existing_jobid FROM cron.job
   WHERE jobname = 'classify-discovered-salons-nightly';
  IF v_existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_jobid);
  END IF;
END$$;

SELECT cron.schedule(
  'classify-discovered-salons-nightly',
  '15 3 * * *',
  $$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/classify-discovered-salons',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    ) AS request_id;
  $$
);
