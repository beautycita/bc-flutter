-- Schedule follow-up reminder job
-- Runs daily at 10:00 AM Mexico City time (UTC-6)
-- Calls the scheduled-followup edge function

-- Enable pg_cron extension (Supabase Pro feature)
-- Note: This requires pg_cron to be enabled in Supabase dashboard first
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Add tracking columns to discovered_salons if not exist
ALTER TABLE discovered_salons
ADD COLUMN IF NOT EXISTS first_selected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_selected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_outreach_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS outreach_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS outreach_channel TEXT;

-- Index for efficient follow-up queries
CREATE INDEX IF NOT EXISTS idx_discovered_salons_followup
ON discovered_salons(first_selected_at, status, outreach_count)
WHERE first_selected_at IS NOT NULL
  AND status NOT IN ('registered', 'declined', 'unreachable');

-- Comment explaining the scheduled job setup
COMMENT ON TABLE discovered_salons IS
'Salon leads discovered via scraping. Follow-up schedule:
- 24h after first selection: first reminder
- 7 days: weekly reminder
- Max 10 outreach attempts
- 48h minimum between messages
Schedule via pg_cron (Supabase Pro) or external scheduler calling scheduled-followup edge function.';

-- To enable pg_cron job (run manually after enabling extension):
-- SELECT cron.schedule(
--   'follow-up-reminders',
--   '0 16 * * *',  -- 16:00 UTC = 10:00 Mexico City
--   $$
--   SELECT net.http_post(
--     url := 'https://YOUR_PROJECT.supabase.co/functions/v1/scheduled-followup',
--     headers := '{"Authorization": "Bearer YOUR_CRON_SECRET"}'::jsonb
--   );
--   $$
-- );
