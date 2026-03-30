-- Marketing: automated follow-up messages
CREATE TABLE IF NOT EXISTS automated_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  trigger_type text NOT NULL,
  delay_hours integer NOT NULL DEFAULT 24,
  channel text NOT NULL DEFAULT 'push',
  message_template text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT automated_messages_unique UNIQUE (business_id, trigger_type)
);

CREATE INDEX IF NOT EXISTS idx_automated_messages_biz ON automated_messages(business_id);
ALTER TABLE automated_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY automated_messages_owner ON automated_messages
  FOR ALL USING (
    business_id IN (SELECT id FROM businesses WHERE owner_id = auth.uid())
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  );

CREATE TABLE IF NOT EXISTS automated_message_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automated_message_id uuid REFERENCES automated_messages(id) ON DELETE SET NULL,
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  trigger_type text NOT NULL,
  channel text NOT NULL,
  status text NOT NULL DEFAULT 'sent',
  appointment_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auto_msg_log_biz ON automated_message_log(business_id, created_at);
