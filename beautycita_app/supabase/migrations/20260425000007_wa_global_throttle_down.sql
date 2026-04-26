-- Down: WA global throttle

DROP FUNCTION IF EXISTS wa_queue_watchdog();
DROP FUNCTION IF EXISTS mark_wa_message_failed(uuid, text, int);
DROP FUNCTION IF EXISTS mark_wa_message_sent(uuid);
DROP FUNCTION IF EXISTS claim_next_wa_message();
DROP FUNCTION IF EXISTS enqueue_wa_message(text, text, int, text, text, jsonb, timestamptz);

ALTER TABLE wa_message_queue DROP CONSTRAINT IF EXISTS wa_message_queue_status_check;
ALTER TABLE wa_message_queue ADD CONSTRAINT wa_message_queue_status_check
  CHECK (status IN ('pending', 'sent', 'failed'));

DROP INDEX IF EXISTS uq_wa_queue_idempotency;
DROP INDEX IF EXISTS idx_wa_queue_drain_order;
CREATE INDEX IF NOT EXISTS idx_wa_queue_pending
  ON wa_message_queue (next_retry_at) WHERE status = 'pending';

ALTER TABLE wa_message_queue
  DROP COLUMN IF EXISTS priority,
  DROP COLUMN IF EXISTS scheduled_for,
  DROP COLUMN IF EXISTS source,
  DROP COLUMN IF EXISTS idempotency_key,
  DROP COLUMN IF EXISTS sent_at;

DROP TABLE IF EXISTS wa_send_pace CASCADE;
