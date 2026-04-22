-- =============================================================================
-- Migration: 20260422000002_stylist_appointment_reminder.sql
-- Description: Support for the T-5min pre-appointment stylist reminder.
-- Adds a dedupe column on appointments (stylist_reminded_at) so the cron
-- loop never double-sends. Partial index on the common query
-- (stylist_reminded_at IS NULL AND starts_at ≈ now() + 5min) keeps the
-- reminder scan cheap.
-- =============================================================================

ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS stylist_reminded_at timestamptz;

COMMENT ON COLUMN public.appointments.stylist_reminded_at IS
  'Timestamp when the T-5min pre-appointment reminder was sent to the '
  'stylist (via push + WA fallback). NULL = not yet reminded. Set by '
  'stylist-appointment-reminder edge function; dedupes the 2-minute cron '
  'scan so a single appointment gets exactly one nudge.';

-- Fast lookup for the reminder scan: appointments needing a reminder in
-- the near future. Partial index excludes historical + already-reminded
-- rows, keeping it tiny.
CREATE INDEX IF NOT EXISTS idx_appointments_stylist_reminder_due
  ON public.appointments (starts_at)
  WHERE stylist_reminded_at IS NULL
    AND status NOT IN ('cancelled', 'completed', 'no_show');
