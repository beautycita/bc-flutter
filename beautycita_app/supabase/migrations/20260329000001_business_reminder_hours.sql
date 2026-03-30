-- Configurable reminder window per business (hours before appointment)
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS reminder_hours integer DEFAULT 2;
COMMENT ON COLUMN businesses.reminder_hours IS 'Hours before appointment to send reminder notification (default 2)';
