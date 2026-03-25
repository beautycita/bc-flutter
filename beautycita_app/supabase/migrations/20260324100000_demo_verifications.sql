CREATE TABLE IF NOT EXISTS demo_verifications (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone TEXT NOT NULL,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  verified_at TIMESTAMPTZ,
  demo_opened_at TIMESTAMPTZ,
  demo_closed_at TIMESTAMPTZ,
  followup_sent_at TIMESTAMPTZ,
  second_followup_sent_at TIMESTAMPTZ,
  app_registered BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_demo_verif_phone ON demo_verifications (phone, created_at DESC);

ALTER TABLE demo_verifications ENABLE ROW LEVEL SECURITY;

-- Service role only
CREATE POLICY "service_role_full" ON demo_verifications FOR ALL TO service_role USING (true) WITH CHECK (true);
