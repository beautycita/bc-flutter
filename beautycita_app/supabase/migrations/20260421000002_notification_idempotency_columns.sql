-- =============================================================================
-- Migration: 20260421000002_notification_idempotency_columns.sql
-- Description: Add notify-once flags for reschedule + cancel events so
-- caller retries (network flakes, double-clicks, edge function timeouts)
-- don't fan out duplicate WA + push to the customer.
--
-- Pattern: atomic UPDATE WHERE *_notified_at IS NULL — same compare-and-swap
-- as booking-reminder.reminded_at (which already works correctly).
-- =============================================================================

ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS reschedule_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancel_notified_at timestamptz;

COMMENT ON COLUMN public.appointments.reschedule_notified_at IS
  'Set by reschedule-notification atomic claim. NULL = never notified for the '
  'CURRENT reschedule. Cleared by the reschedule RPC when starts_at changes.';
COMMENT ON COLUMN public.appointments.cancel_notified_at IS
  'Set by cancel-notification atomic claim. Once set, never cleared (cancel is terminal).';

-- When a reschedule actually changes starts_at, clear the flag so the next
-- reschedule can re-notify. Triggered on UPDATE of starts_at.
CREATE OR REPLACE FUNCTION public.clear_reschedule_notified_on_starts_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.starts_at IS DISTINCT FROM OLD.starts_at THEN
    NEW.reschedule_notified_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS appointments_clear_reschedule_notified ON public.appointments;
CREATE TRIGGER appointments_clear_reschedule_notified
  BEFORE UPDATE OF starts_at ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.clear_reschedule_notified_on_starts_change();
