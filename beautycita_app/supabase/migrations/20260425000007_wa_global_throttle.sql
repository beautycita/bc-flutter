-- =============================================================================
-- WA global throttle: 1 message per 20s, all senders
-- =============================================================================
-- Every WA send across the platform now flows through wa_message_queue.
-- A single pace row enforces 20s minimum spacing; drainer respects it.
-- Priority field lets transactional traffic (OTPs, chat replies) jump bulk.
-- =============================================================================

-- ── 1. Pace singleton ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wa_send_pace (
  id smallint PRIMARY KEY DEFAULT 1,
  last_send_at timestamptz NOT NULL DEFAULT (now() - interval '1 hour'),
  min_spacing_seconds int NOT NULL DEFAULT 20,
  CHECK (id = 1)
);

INSERT INTO wa_send_pace (id) VALUES (1) ON CONFLICT DO NOTHING;

ALTER TABLE wa_send_pace ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wa_send_pace: service_role all"
  ON wa_send_pace FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "wa_send_pace: admin read"
  ON wa_send_pace FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','superadmin')));

-- ── 2. Extend wa_message_queue: now PRIMARY path, not just retry ────────────
ALTER TABLE wa_message_queue
  ADD COLUMN IF NOT EXISTS priority int NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS scheduled_for timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS idempotency_key text,
  ADD COLUMN IF NOT EXISTS sent_at timestamptz;

-- Priority levels:
--  0 = critical (OTP, security)
--  3 = transactional (booking confirmation, chat reply, walk-in)
--  5 = normal (default)
--  7 = informational (reminders, follow-ups)
--  9 = bulk/marketing (outreach, demo funnel)
COMMENT ON COLUMN wa_message_queue.priority IS
  'Lower = higher priority. 0 critical, 3 transactional, 5 default, 7 informational, 9 bulk.';

-- Idempotency: prevent duplicate enqueue of the same logical send.
CREATE UNIQUE INDEX IF NOT EXISTS uq_wa_queue_idempotency
  ON wa_message_queue (idempotency_key)
  WHERE idempotency_key IS NOT NULL AND status = 'pending';

-- Drain order: priority asc, scheduled_for asc, created_at asc.
DROP INDEX IF EXISTS idx_wa_queue_pending;
CREATE INDEX IF NOT EXISTS idx_wa_queue_drain_order
  ON wa_message_queue (priority, scheduled_for, created_at)
  WHERE status = 'pending';

-- ── 3. Atomic enqueue helper (race-safe) ────────────────────────────────────
CREATE OR REPLACE FUNCTION enqueue_wa_message(
  p_phone text,
  p_message text,
  p_priority int DEFAULT 5,
  p_source text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_scheduled_for timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_phone IS NULL OR p_phone = '' OR p_message IS NULL OR p_message = '' THEN
    RAISE EXCEPTION 'phone and message required';
  END IF;

  INSERT INTO wa_message_queue (phone, message, status, priority, source, idempotency_key, metadata, scheduled_for)
  VALUES (p_phone, p_message, 'pending', COALESCE(p_priority, 5), p_source, p_idempotency_key, COALESCE(p_metadata, '{}'::jsonb), COALESCE(p_scheduled_for, now()))
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL AND status = 'pending'
  DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    -- Conflict with existing pending row — return that row's id
    SELECT id INTO v_id FROM wa_message_queue
     WHERE idempotency_key = p_idempotency_key AND status = 'pending'
     LIMIT 1;
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION enqueue_wa_message(text, text, int, text, text, jsonb, timestamptz) TO service_role, authenticated;

-- ── 4. Atomic claim-next: respects pace + priority + skip locked ────────────
CREATE OR REPLACE FUNCTION claim_next_wa_message()
RETURNS TABLE (
  id uuid,
  phone text,
  message text,
  attempts int,
  max_attempts int,
  metadata jsonb,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pace record;
  v_now timestamptz := now();
  v_min_spacing int;
  v_claimed uuid;
BEGIN
  SELECT * INTO v_pace FROM wa_send_pace WHERE id = 1 FOR UPDATE;
  v_min_spacing := COALESCE(v_pace.min_spacing_seconds, 20);

  -- Honor 20s pace gate. If too soon, return nothing.
  IF v_now < v_pace.last_send_at + make_interval(secs => v_min_spacing) THEN
    RETURN;
  END IF;

  -- Pull the next eligible message in priority/schedule order.
  WITH next_row AS (
    SELECT q.id
      FROM wa_message_queue q
     WHERE q.status = 'pending'
       AND q.scheduled_for <= v_now
       AND q.attempts < q.max_attempts
     ORDER BY q.priority ASC, q.scheduled_for ASC, q.created_at ASC
     LIMIT 1
     FOR UPDATE SKIP LOCKED
  )
  UPDATE wa_message_queue q
     SET status = 'sending',
         attempts = q.attempts + 1
    FROM next_row
   WHERE q.id = next_row.id
   RETURNING q.id INTO v_claimed;

  IF v_claimed IS NULL THEN
    RETURN;
  END IF;

  -- Reserve the pace slot now (before the actual send) so concurrent claimers
  -- can't grab another slot inside the 20s window.
  UPDATE wa_send_pace SET last_send_at = v_now WHERE id = 1;

  RETURN QUERY
  SELECT q.id, q.phone, q.message, q.attempts, q.max_attempts, q.metadata, q.source
    FROM wa_message_queue q
   WHERE q.id = v_claimed;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_next_wa_message() TO service_role;

-- ── 5. Mark result helpers ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION mark_wa_message_sent(p_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE wa_message_queue
     SET status = 'sent', sent_at = now()
   WHERE id = p_id;
$$;

CREATE OR REPLACE FUNCTION mark_wa_message_failed(
  p_id uuid,
  p_error text,
  p_retry_in_seconds int DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  SELECT * INTO v_row FROM wa_message_queue WHERE id = p_id;
  IF v_row IS NULL THEN RETURN; END IF;

  IF v_row.attempts >= v_row.max_attempts THEN
    UPDATE wa_message_queue
       SET status = 'failed', last_error = p_error
     WHERE id = p_id;
  ELSE
    UPDATE wa_message_queue
       SET status = 'pending',
           last_error = p_error,
           scheduled_for = now() + make_interval(secs => COALESCE(p_retry_in_seconds, 60))
     WHERE id = p_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_wa_message_sent(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION mark_wa_message_failed(uuid, text, int) TO service_role;

-- ── 6. Status constraint widening to allow 'sending' transient ──────────────
ALTER TABLE wa_message_queue DROP CONSTRAINT IF EXISTS wa_message_queue_status_check;
ALTER TABLE wa_message_queue ADD CONSTRAINT wa_message_queue_status_check
  CHECK (status IN ('pending', 'sending', 'sent', 'failed'));

-- ── 7. Watchdog: requeue 'sending' rows stuck > 2 min (drainer crashed) ─────
CREATE OR REPLACE FUNCTION wa_queue_watchdog()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

GRANT EXECUTE ON FUNCTION wa_queue_watchdog() TO service_role;
