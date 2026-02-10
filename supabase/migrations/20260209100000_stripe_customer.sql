-- Add stripe_customer_id to profiles for Stripe payment method management
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS stripe_customer_id text;
