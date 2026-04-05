-- =============================================================================
-- 1. Add booking_source to appointments
--    Distinguishes how the booking originated — critical for the 0% fee strategy
--    (salons pay nothing for their own clients, 3% only for BC-sourced clients).
-- =============================================================================

ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS booking_source text NOT NULL DEFAULT 'salon_direct'
  CHECK (booking_source IN ('bc_marketplace', 'salon_direct', 'walk_in', 'cita_express', 'invite_link'));

COMMENT ON COLUMN appointments.booking_source IS
  'How this booking originated: bc_marketplace (user found salon via BC search), salon_direct (salon''s own client booked via their link), walk_in (registered at salon), cita_express (QR code), invite_link (shared invite link).';

-- 2. Prevent duplicate commission records for the same appointment+source
ALTER TABLE commission_records
  ADD CONSTRAINT commission_records_unique_appt_source
  UNIQUE (appointment_id, source);

-- 3. Index for fast source-based queries (dashboard, fee reporting)
CREATE INDEX IF NOT EXISTS idx_appointments_booking_source
  ON appointments(business_id, booking_source)
  WHERE status NOT IN ('cancelled_customer', 'cancelled_business');
