-- Chat overhaul foundation (2026-04-19)
--
-- Two gaps blocked the chat feature from being usable end-to-end:
-- (1) No unique constraint on chat_threads(user_id, contact_type, contact_id)
--     → upserts fail, duplicate threads possible.
-- (2) No RLS allowing business owners to SELECT their salon threads or
--     INSERT responses → customers sent messages into the void; the salon
--     side literally could not see or reply.
--
-- This migration closes both. sender_type='salon' is already allowed by
-- the existing chat_messages_sender_type_check constraint, so no enum
-- change is needed — businesses write with that sender_type.

BEGIN;

-- 1. Unique constraint — partial index skips NULL contact_ids (AI threads
-- like aphrodite/eros don't have a contact_id and should not participate).
CREATE UNIQUE INDEX IF NOT EXISTS chat_threads_user_contact_uniq
  ON chat_threads (user_id, contact_type, contact_id)
  WHERE contact_id IS NOT NULL;

-- 2a. Business owner can read threads pointing at their business.
-- contact_id is text, businesses.id is uuid — cast uuid→text on the right.
DROP POLICY IF EXISTS "chat_threads_business_read" ON chat_threads;
CREATE POLICY "chat_threads_business_read"
  ON chat_threads FOR SELECT
  USING (
    contact_type = 'salon'
    AND contact_id IN (
      SELECT id::text FROM businesses WHERE owner_id = auth.uid()
    )
  );

-- 2b. Business owner can update the thread they own (mark read, refresh
-- last_message_at, pin, archive). No INSERT on chat_threads from business
-- side — customers always initiate.
DROP POLICY IF EXISTS "chat_threads_business_update" ON chat_threads;
CREATE POLICY "chat_threads_business_update"
  ON chat_threads FOR UPDATE
  USING (
    contact_type = 'salon'
    AND contact_id IN (
      SELECT id::text FROM businesses WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    contact_type = 'salon'
    AND contact_id IN (
      SELECT id::text FROM businesses WHERE owner_id = auth.uid()
    )
  );

-- 3a. Business owner can read messages in threads they own.
DROP POLICY IF EXISTS "chat_messages_business_read" ON chat_messages;
CREATE POLICY "chat_messages_business_read"
  ON chat_messages FOR SELECT
  USING (
    thread_id IN (
      SELECT ct.id
      FROM chat_threads ct
      JOIN businesses b ON ct.contact_id = b.id::text
      WHERE ct.contact_type = 'salon' AND b.owner_id = auth.uid()
    )
  );

-- 3b. Business owner can insert messages with sender_type='salon' only.
-- The WITH CHECK gate ensures a business owner can't impersonate a user.
DROP POLICY IF EXISTS "chat_messages_business_insert" ON chat_messages;
CREATE POLICY "chat_messages_business_insert"
  ON chat_messages FOR INSERT
  WITH CHECK (
    sender_type = 'salon'
    AND thread_id IN (
      SELECT ct.id
      FROM chat_threads ct
      JOIN businesses b ON ct.contact_id = b.id::text
      WHERE ct.contact_type = 'salon' AND b.owner_id = auth.uid()
    )
  );

-- 4. Index to speed up the new lookup pattern businesses will hit most:
-- "show me my active threads, newest message first."
CREATE INDEX IF NOT EXISTS chat_threads_contact_type_id_last_msg_idx
  ON chat_threads (contact_type, contact_id, last_message_at DESC)
  WHERE contact_id IS NOT NULL;

-- 5. Trigger: whenever a new chat_message lands, bump the parent thread's
-- last_message_text + last_message_at + unread_count for the OTHER party.
-- Prevents thread list from going stale and makes unread badges work.
CREATE OR REPLACE FUNCTION chat_message_after_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_threads
     SET last_message_text = CASE
           WHEN NEW.content_type = 'text' THEN NEW.text_content
           WHEN NEW.content_type = 'image' THEN '[imagen]'
           WHEN NEW.content_type = 'tryon_result' THEN '[prueba virtual]'
           WHEN NEW.content_type = 'booking_card' THEN '[cita]'
           ELSE '[mensaje]'
         END,
         last_message_at = NEW.created_at,
         unread_count = COALESCE(unread_count, 0) +
           CASE WHEN NEW.sender_type = 'user' THEN 0 ELSE 1 END
   WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS chat_messages_after_insert ON chat_messages;
CREATE TRIGGER chat_messages_after_insert
  AFTER INSERT ON chat_messages
  FOR EACH ROW EXECUTE FUNCTION chat_message_after_insert();

COMMIT;
