-- Add verify_token column to qr_auth_sessions for secure verify flow.
-- Only the web client that created the session knows the verify_token,
-- preventing session_id guessing attacks.

ALTER TABLE qr_auth_sessions
  ADD COLUMN IF NOT EXISTS verify_token TEXT;

-- Restrict verify_token from being readable via anon/authenticated roles.
-- Only the service role (used by the edge function) can read it.
REVOKE SELECT ON qr_auth_sessions FROM anon;

-- Re-grant SELECT on specific columns only (no verify_token, no email_otp)
GRANT SELECT (id, code, status, user_id, email, authorized_at, consumed_at, expires_at, created_at)
  ON qr_auth_sessions TO anon;

GRANT SELECT (id, code, status, user_id, email, authorized_at, consumed_at, expires_at, created_at)
  ON qr_auth_sessions TO authenticated;
