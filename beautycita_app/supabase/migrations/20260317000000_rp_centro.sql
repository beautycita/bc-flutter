-- RP Centro de Comunicaciones — new tables + columns
-- rp_checklist: manual onboarding checklist per salon
-- rp_meetings: meeting scheduling between RP and salon
-- rp_assignments: add close-out columns

-- ── rp_checklist ──

CREATE TABLE IF NOT EXISTS rp_checklist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id uuid NOT NULL REFERENCES discovered_salons(id) ON DELETE CASCADE,
  rp_user_id uuid NOT NULL REFERENCES profiles(id),
  item_key text NOT NULL,
  checked_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT rp_checklist_unique UNIQUE (discovered_salon_id, item_key)
);

CREATE INDEX idx_rp_checklist_salon ON rp_checklist(discovered_salon_id);

ALTER TABLE rp_checklist ENABLE ROW LEVEL SECURITY;

-- RPs can CRUD their own checklist items
CREATE POLICY rp_checklist_rp_select ON rp_checklist FOR SELECT USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_checklist_rp_insert ON rp_checklist FOR INSERT WITH CHECK (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_checklist_rp_update ON rp_checklist FOR UPDATE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_checklist_rp_delete ON rp_checklist FOR DELETE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);

-- ── rp_meetings ──

CREATE TABLE IF NOT EXISTS rp_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id uuid NOT NULL REFERENCES discovered_salons(id) ON DELETE CASCADE,
  rp_user_id uuid NOT NULL REFERENCES profiles(id),
  proposed_at timestamptz NOT NULL,
  confirmed_at timestamptz,
  salon_proposed_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'denied', 'rescheduled')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_rp_meetings_salon ON rp_meetings(discovered_salon_id);
CREATE INDEX idx_rp_meetings_rp ON rp_meetings(rp_user_id);

ALTER TABLE rp_meetings ENABLE ROW LEVEL SECURITY;

CREATE POLICY rp_meetings_rp_select ON rp_meetings FOR SELECT USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_meetings_rp_insert ON rp_meetings FOR INSERT WITH CHECK (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_meetings_rp_update ON rp_meetings FOR UPDATE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_meetings_rp_delete ON rp_meetings FOR DELETE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);

-- ── rp_assignments: add close-out columns ──

ALTER TABLE rp_assignments
  ADD COLUMN IF NOT EXISTS closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS close_outcome text CHECK (close_outcome IN ('completed', 'not_converted')),
  ADD COLUMN IF NOT EXISTS close_reason text;
