-- Aphrodite AI copy generation rate limiting log
CREATE TABLE IF NOT EXISTS public.aphrodite_copy_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  field_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for rate limit lookups
CREATE INDEX idx_aphrodite_copy_log_user_time
  ON public.aphrodite_copy_log (user_id, created_at DESC);

-- RLS: users can only see their own logs (not really needed but safe)
ALTER TABLE public.aphrodite_copy_log ENABLE ROW LEVEL SECURITY;

-- Service role can do everything (edge function uses service role)
CREATE POLICY "service_role_full_access" ON public.aphrodite_copy_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Auto-cleanup: delete logs older than 24 hours (optional, keeps table small)
-- Can be run via cron or left to grow (small rows)
