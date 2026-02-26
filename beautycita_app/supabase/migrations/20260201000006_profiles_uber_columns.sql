-- Add Uber account linking columns to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS uber_linked BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS uber_access_token TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS uber_refresh_token TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS uber_token_expires_at TIMESTAMPTZ;
