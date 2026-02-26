-- Add last_seen column for online presence detection
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_seen timestamptz;

-- Index for efficient online user queries
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen
  ON public.profiles(last_seen DESC NULLS LAST);
