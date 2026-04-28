-- Restore the requeue-on-stuck behaviour.
-- Note: this re-introduces the duplicate-WA delivery race that 0004_up
-- closed. Don't run unless bpi gains its own idempotency layer first.

CREATE OR REPLACE FUNCTION wa_queue_watchdog()
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE wa_message_queue
     SET status = 'pending',
         last_error = COALESCE(last_error, '') || ' [watchdog requeue]'
   WHERE status = 'sending'
     AND created_at < now() - interval '2 minutes';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
