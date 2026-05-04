-- =============================================================================
-- 20260504000003 — schedule wa-queue-drain cron
-- =============================================================================
-- The qr-walkin-assign edge function inserts the client confirmation into
-- wa_notification_queue (template-based queue keyed on phone+template+vars).
-- Only consumer is wa-queue-drain, which renders the template and re-enqueues
-- into the global throttle queue (wa_message_queue, drained by wa-global-drain).
--
-- The drainer was never put on a cron schedule. Result: walkin_confirmed
-- messages from the QR free-tier flow sit in wa_notification_queue forever
-- and clients never receive their "your appointment is at X with stylist Y"
-- alert — exactly the alert the spec requires.
--
-- Caught 2026-05-04 during the pre-flight audit before the first live free-QR
-- demo. Schedules the drainer every minute, mirroring cash-trust-notify-drain.
-- =============================================================================

DO $$
DECLARE v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'wa-queue-drain';
  IF v_jobid IS NOT NULL THEN PERFORM cron.unschedule(v_jobid); END IF;
END $$;

SELECT cron.schedule(
  'wa-queue-drain',
  '* * * * *',
  $cron$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/wa-queue-drain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    ) AS request_id;
  $cron$
);
