-- Add support_ai contact type and eros sender type for Eros AI support agent

ALTER TABLE chat_threads
  DROP CONSTRAINT IF EXISTS chat_threads_contact_type_check;
ALTER TABLE chat_threads
  ADD CONSTRAINT chat_threads_contact_type_check
  CHECK (contact_type IN ('aphrodite', 'salon', 'user', 'support', 'support_ai'));

ALTER TABLE chat_messages
  DROP CONSTRAINT IF EXISTS chat_messages_sender_type_check;
ALTER TABLE chat_messages
  ADD CONSTRAINT chat_messages_sender_type_check
  CHECK (sender_type IN ('user', 'aphrodite', 'salon', 'system', 'support', 'eros'));
