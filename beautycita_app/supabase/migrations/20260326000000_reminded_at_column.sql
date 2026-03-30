-- Add reminded_at column to appointments for booking reminder tracking.
-- Required by the booking-reminder edge function cron job.
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS reminded_at timestamptz;

COMMENT ON COLUMN appointments.reminded_at IS 'When the booking reminder notification was sent. Null = not yet reminded.';

-- Index for efficient reminder queries (find un-reminded upcoming appointments)
CREATE INDEX IF NOT EXISTS idx_appointments_reminded_at
  ON appointments (starts_at)
  WHERE reminded_at IS NULL AND status IN ('pending', 'confirmed');
