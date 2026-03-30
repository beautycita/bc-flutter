-- Add stripe_details_submitted column referenced by stripe-webhook handler.
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS stripe_details_submitted boolean DEFAULT false;

COMMENT ON COLUMN businesses.stripe_details_submitted IS 'Whether Stripe has confirmed all required details are submitted for the Express account.';
