-- =============================================================================
-- Schedule cron drain for outreach-bulk-send (WA + email)
-- =============================================================================
-- Two cron entries (one per channel) so they can run in parallel and stay
-- within Deno edge fn 60s timeout. Auth via X-Cron-Secret + private.cron_config.
-- =============================================================================

-- Re-use the private.cron_config table + secret seeded by 20260423000005.
-- If this migration applies before that one (shouldn't), guard:
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
  SELECT jobid INTO v_existing_jobid FROM cron.job WHERE jobname = 'outreach-bulk-drain-wa';
  IF v_existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_jobid);
  END IF;
  SELECT jobid INTO v_existing_jobid FROM cron.job WHERE jobname = 'outreach-bulk-drain-email';
  IF v_existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_jobid);
  END IF;
END$$;

-- WhatsApp drainer: every minute. Inside the fn it processes up to 8 recipients
-- with a 4s sleep between sends — about 32s of wall time, leaving headroom.
SELECT cron.schedule(
  'outreach-bulk-drain-wa',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/outreach-bulk-send',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := jsonb_build_object('action','drain','channel','wa'),
      timeout_milliseconds := 55000
    ) AS request_id;
  $$
);

-- Email drainer: every minute, up to 30 recipients @ 1s pacing.
SELECT cron.schedule(
  'outreach-bulk-drain-email',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/outreach-bulk-send',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := jsonb_build_object('action','drain','channel','email'),
      timeout_milliseconds := 45000
    ) AS request_id;
  $$
);
