-- Salon Invite Experience: cached Aphrodite bios + user invite tracking

-- Add cached Aphrodite bio to discovered salons
ALTER TABLE discovered_salons
  ADD COLUMN IF NOT EXISTS generated_bio TEXT;

-- Track user-initiated salon invites
CREATE TABLE IF NOT EXISTS user_salon_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  discovered_salon_id UUID NOT NULL REFERENCES discovered_salons(id) ON DELETE CASCADE,
  invite_message TEXT NOT NULL,
  platform_message_sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_salon_invites_user
  ON user_salon_invites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_salon_invites_salon
  ON user_salon_invites(discovered_salon_id);

-- RLS
ALTER TABLE user_salon_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own invites"
  ON user_salon_invites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create invites"
  ON user_salon_invites FOR INSERT
  WITH CHECK (auth.uid() = user_id);
