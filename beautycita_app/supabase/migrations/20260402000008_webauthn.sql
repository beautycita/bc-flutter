-- WebAuthn (passkey) support tables
-- Stores registered credentials and temporary challenges

CREATE TABLE webauthn_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  credential_id text NOT NULL UNIQUE,
  public_key bytea NOT NULL,
  sign_count integer NOT NULL DEFAULT 0,
  device_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE webauthn_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge text NOT NULL,
  user_id uuid,
  type text NOT NULL CHECK (type IN ('register', 'login')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '5 minutes')
);

CREATE INDEX idx_webauthn_creds_user ON webauthn_credentials(user_id);
CREATE INDEX idx_webauthn_challenges_expires ON webauthn_challenges(expires_at);

-- RLS policies
ALTER TABLE webauthn_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE webauthn_challenges ENABLE ROW LEVEL SECURITY;

-- Credentials: users can read their own, edge functions use service role
CREATE POLICY "Users can view own credentials"
  ON webauthn_credentials FOR SELECT
  USING (auth.uid() = user_id);

-- Challenges: edge functions manage via service role, no direct user access
CREATE POLICY "Service role only"
  ON webauthn_challenges FOR ALL
  USING (false);
