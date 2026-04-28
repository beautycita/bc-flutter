-- WA queue watchdog: stop requeuing 'sending' rows.
--
-- Why: the prior wa_queue_watchdog flipped any 'sending' row older than
-- 2 minutes back to 'pending'. The bpi /api/wa/send call had already
-- accepted the message and delivered it via whatsapp-web.js, but the
-- Deno edge runtime wall-clock-killed the isolate before
-- mark_wa_message_sent could write 'sent'. The drainer then claimed the
-- same row a few seconds later, called bpi again, bpi delivered again,
-- and the user received the verification code three times. Bpi has no
-- idempotency, so each retry is a fresh delivery.
--
-- Fix: mark stale 'sending' rows as 'sent' instead of requeuing. By the
-- time 2 minutes has elapsed, whatsapp-web.js has almost certainly
-- delivered the message; treating it as sent is correct in the dominant
-- failure case (isolate killed after bpi processed). If bpi genuinely
-- never delivered, the 60s dedup window in phone-verify will have
-- elapsed and the user can request another code without colliding with
-- a duplicate already in flight.
--
-- This eliminates the duplicate-WA delivery class entirely. Bpi-side
-- idempotency remains the right long-term answer when we move off
-- whatsapp-web.js to a real BSP.

CREATE OR REPLACE FUNCTION wa_queue_watchdog()
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE wa_message_queue
     SET status = 'sent',
         sent_at = COALESCE(sent_at, now()),
         last_error = COALESCE(last_error, '') || ' [watchdog assumed delivered]'
   WHERE status = 'sending'
     AND created_at < now() - interval '2 minutes';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Heal the two rows currently stuck in pending with attempts=3 — they
-- were the canary that exposed this bug. Marking them sent so they
-- don't get re-attempted on the next cron tick.
UPDATE wa_message_queue
   SET status = 'sent',
       sent_at = COALESCE(sent_at, now()),
       last_error = COALESCE(last_error, '') || ' [manual heal: assumed delivered, watchdog fix]'
 WHERE status = 'pending'
   AND attempts >= max_attempts - 0
   AND last_error ILIKE '%watchdog requeue%';
