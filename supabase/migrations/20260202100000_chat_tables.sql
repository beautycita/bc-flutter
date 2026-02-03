-- =============================================================================
-- Chat system tables for Aphrodite AI and future messaging
-- =============================================================================

-- Chat threads (one per user<>contact pair)
CREATE TABLE chat_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  contact_type text NOT NULL CHECK (contact_type IN ('aphrodite', 'salon', 'user')),
  contact_id text,
  openai_thread_id text,
  last_message_text text,
  last_message_at timestamptz DEFAULT now(),
  unread_count int DEFAULT 0,
  pinned boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Chat messages
CREATE TABLE chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid REFERENCES chat_threads(id) ON DELETE CASCADE NOT NULL,
  sender_type text NOT NULL CHECK (sender_type IN ('user', 'aphrodite', 'salon', 'system')),
  sender_id uuid,
  content_type text NOT NULL DEFAULT 'text' CHECK (content_type IN ('text', 'image', 'tryon_result', 'booking_card', 'system')),
  text_content text,
  media_url text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX idx_chat_threads_user ON chat_threads(user_id);
CREATE INDEX idx_chat_threads_last_msg ON chat_threads(user_id, pinned DESC, last_message_at DESC);
CREATE INDEX idx_chat_messages_thread ON chat_messages(thread_id, created_at DESC);

-- RLS
ALTER TABLE chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own threads" ON chat_threads
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users see own messages" ON chat_messages
  FOR ALL USING (
    thread_id IN (SELECT id FROM chat_threads WHERE user_id = auth.uid())
  );
