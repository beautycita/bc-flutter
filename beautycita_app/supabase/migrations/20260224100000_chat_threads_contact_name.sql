-- Add contact_name column to chat_threads (model expects it but column was never created)
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS contact_name text;

COMMENT ON COLUMN public.chat_threads.contact_name IS 'Display name for salon/user contacts in chat list';
