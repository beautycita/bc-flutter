-- Down: re-create the legacy daily cron pointing at order-followup edge fn
-- (which is currently a no-op stub — no harm if it fires).
SELECT cron.schedule(
  'order-followup',
  '0 9 * * *',
  $cron$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/order-followup',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    ) AS request_id;
  $cron$
);
