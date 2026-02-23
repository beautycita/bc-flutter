-- Support chat: add 'support' contact/sender type + WA chat bridge table

-- 1. Expand contact_type constraint to include 'support'
ALTER TABLE chat_threads
  DROP CONSTRAINT IF EXISTS chat_threads_contact_type_check;
ALTER TABLE chat_threads
  ADD CONSTRAINT chat_threads_contact_type_check
  CHECK (contact_type IN ('aphrodite', 'salon', 'user', 'support'));

-- 2. Expand sender_type constraint to include 'support'
ALTER TABLE chat_messages
  DROP CONSTRAINT IF EXISTS chat_messages_sender_type_check;
ALTER TABLE chat_messages
  ADD CONSTRAINT chat_messages_sender_type_check
  CHECK (sender_type IN ('user', 'aphrodite', 'salon', 'system', 'support'));

-- 3. WA chat bridge: maps app threads to WhatsApp conversations
CREATE TABLE IF NOT EXISTS wa_chat_bridges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  wa_phone text NOT NULL,
  user_phone text,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(thread_id)
);

CREATE INDEX IF NOT EXISTS idx_wa_chat_bridges_thread ON wa_chat_bridges(thread_id);

-- RLS: only service_role should access wa_chat_bridges (edge functions)
ALTER TABLE wa_chat_bridges ENABLE ROW LEVEL SECURITY;
-- No user-facing policies — only service_role key accesses this table

-- 4. Salon outreach log table
CREATE TABLE IF NOT EXISTS salon_outreach_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id uuid REFERENCES discovered_salons(id),
  channel text NOT NULL CHECK (channel IN ('whatsapp', 'sms', 'email')),
  recipient_phone text,
  message_text text,
  interest_count int,
  test_mode boolean DEFAULT false,
  sent_at timestamptz DEFAULT now()
);

ALTER TABLE salon_outreach_log ENABLE ROW LEVEL SECURITY;
-- No user-facing policies — only service_role key accesses this table

-- 5. Helper function to increment unread count atomically
CREATE OR REPLACE FUNCTION increment_unread(p_thread_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE chat_threads
  SET unread_count = COALESCE(unread_count, 0) + 1
  WHERE id = p_thread_id;
$$;
