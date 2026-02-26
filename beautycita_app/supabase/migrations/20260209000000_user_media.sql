-- User media index table for Media Manager
-- Tracks all media items across personal, business, and chat contexts.

CREATE TABLE user_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL DEFAULT 'image' CHECK (media_type IN ('image', 'video')),
  source TEXT NOT NULL CHECK (source IN ('lightx', 'chat', 'upload', 'review', 'portfolio')),
  source_ref UUID,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  metadata JSONB DEFAULT '{}',
  section TEXT NOT NULL CHECK (section IN ('personal', 'business', 'chat')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_media_user_section ON user_media(user_id, section, created_at DESC);
CREATE INDEX idx_user_media_user_source ON user_media(user_id, source);

ALTER TABLE user_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own media"
  ON user_media FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own media"
  ON user_media FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own media"
  ON user_media FOR DELETE
  USING (auth.uid() = user_id);
