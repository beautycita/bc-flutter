-- =============================================================================
-- Schedule cron drain for wa-global-drain (1 msg / 20s, 3 msgs / min)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE IF NOT EXISTS private.cron_config (
  id smallint PRIMARY KEY DEFAULT 1,
  cron_secret text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 1)
);

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
  SELECT jobid INTO v_existing_jobid FROM cron.job WHERE jobname = 'wa-global-drain';
  IF v_existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_jobid);
  END IF;
END$$;

SELECT cron.schedule(
  'wa-global-drain',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/wa-global-drain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 58000
    ) AS request_id;
  $$
);
