-- =============================================================================
-- WA message queue: retry mechanism for failed WhatsApp messages (#32)
-- =============================================================================

CREATE TABLE IF NOT EXISTS wa_message_queue (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       text        NOT NULL,
  message     text        NOT NULL,
  status      text        NOT NULL DEFAULT 'pending',
  attempts    integer     NOT NULL DEFAULT 0,
  max_attempts integer    NOT NULL DEFAULT 3,
  created_at  timestamptz NOT NULL DEFAULT now(),
  next_retry_at timestamptz NOT NULL DEFAULT now(),
  last_error  text,
  metadata    jsonb       NOT NULL DEFAULT '{}',

  CONSTRAINT wa_message_queue_status_check CHECK (
    status IN ('pending', 'sent', 'failed')
  )
);

COMMENT ON TABLE wa_message_queue IS
  'Retry queue for failed WhatsApp messages. Processed by marketing-automation cron.';

CREATE INDEX idx_wa_queue_pending
  ON wa_message_queue(next_retry_at)
  WHERE status = 'pending';

CREATE INDEX idx_wa_queue_status
  ON wa_message_queue(status, created_at);

-- RLS: service_role only (edge functions)
ALTER TABLE wa_message_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wa_message_queue: service_role all"
  ON wa_message_queue FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- Admin read access
CREATE POLICY "wa_message_queue: admin read"
  ON wa_message_queue FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  );
