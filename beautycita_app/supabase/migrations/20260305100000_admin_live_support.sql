-- =============================================================================
-- Admin Live Support: RLS policies for admin to send support messages
-- Date: 2026-03-05
-- =============================================================================

BEGIN;

-- Admin can INSERT support messages into chat_messages
CREATE POLICY IF NOT EXISTS "chat_messages_admin_insert_support"
  ON public.chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_admin()
    AND sender_type = 'support'
  );

-- Admin can UPDATE chat_threads (last_message_text, last_message_at, etc.)
CREATE POLICY IF NOT EXISTS "chat_threads_admin_update"
  ON public.chat_threads
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can INSERT support threads
CREATE POLICY IF NOT EXISTS "chat_threads_admin_insert_support"
  ON public.chat_threads
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_admin()
    AND contact_type = 'support'
  );

COMMIT;
