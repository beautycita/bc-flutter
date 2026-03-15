-- Add payment_method column to appointments for tracking how the customer pays.
-- cash_direct = pay stylist in person, no platform processing, no tax retention.
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS payment_method text;

-- Add cash_direct to the payments table constraint.
-- Drop and recreate since ALTER CONSTRAINT isn't supported.
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_method_check;
ALTER TABLE payments ADD CONSTRAINT payments_method_check CHECK (
  payment_method IN ('card', 'oxxo', 'cash', 'cash_direct')
);

COMMENT ON COLUMN appointments.payment_method IS 'Payment method: card, oxxo, cash_direct. Null for legacy bookings.';
