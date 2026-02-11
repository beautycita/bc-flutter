-- Add Stripe Connect fields to businesses table
-- Supports Express accounts for salon payouts

ALTER TABLE businesses
ADD COLUMN IF NOT EXISTS stripe_account_id TEXT,
ADD COLUMN IF NOT EXISTS stripe_onboarding_status TEXT DEFAULT 'not_started',
ADD COLUMN IF NOT EXISTS stripe_charges_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS stripe_payouts_enabled BOOLEAN DEFAULT FALSE;

-- Index for looking up businesses by Stripe account
CREATE INDEX IF NOT EXISTS idx_businesses_stripe_account_id
ON businesses(stripe_account_id)
WHERE stripe_account_id IS NOT NULL;

-- Comment explaining the statuses
COMMENT ON COLUMN businesses.stripe_onboarding_status IS
'Status of Stripe Connect onboarding: not_started, pending, pending_verification, complete';

-- Businesses are not "live" until Stripe is set up
-- This function checks if a business can accept payments
CREATE OR REPLACE FUNCTION is_business_payment_ready(biz_id UUID)
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT stripe_charges_enabled AND stripe_payouts_enabled
     FROM businesses
     WHERE id = biz_id),
    FALSE
  );
$$ LANGUAGE SQL STABLE;
