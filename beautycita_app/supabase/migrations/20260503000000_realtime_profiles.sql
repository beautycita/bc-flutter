-- Add public.profiles to the supabase_realtime publication so clients
-- (e.g., saldo display, status banner) get push updates instead of needing
-- a manual refetch / app restart.
--
-- Safety:
--   * profiles already has self-read RLS, so Realtime only delivers
--     each user's own row to that user.
--   * Admins also get all rows (matches existing read policies).
--
-- Use case: BC observed saldo top-up did not appear until app restart.

ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
