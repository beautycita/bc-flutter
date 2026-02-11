-- Add FCM token support to profiles table
-- Enables server-side push notifications via Firebase Cloud Messaging

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS fcm_updated_at TIMESTAMPTZ;

-- Also add FCM token to businesses for provider notifications
ALTER TABLE businesses
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS fcm_updated_at TIMESTAMPTZ;

-- Index for efficient token lookup
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token
ON profiles(fcm_token)
WHERE fcm_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_businesses_fcm_token
ON businesses(fcm_token)
WHERE fcm_token IS NOT NULL;

-- Comment explaining usage
COMMENT ON COLUMN profiles.fcm_token IS 'Firebase Cloud Messaging token for push notifications to client app';
COMMENT ON COLUMN businesses.fcm_token IS 'Firebase Cloud Messaging token for push notifications to provider app';
