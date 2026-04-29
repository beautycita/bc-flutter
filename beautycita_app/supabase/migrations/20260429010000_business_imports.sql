-- business_imports: audit log for the universal CSV/JSON/XML importer.
-- One row per import session (preview + commit are tied by session_id).

CREATE TABLE IF NOT EXISTS business_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  imported_by uuid NOT NULL REFERENCES auth.users(id),
  source_hint text,                       -- best-guess provider label (fresha, square, generic, etc)
  detected_format text,                   -- csv | json | xml
  entity text NOT NULL DEFAULT 'clients', -- clients | services | appointments (v1: clients only)
  file_name text,
  total_rows integer NOT NULL DEFAULT 0,
  imported_count integer NOT NULL DEFAULT 0,
  updated_count integer NOT NULL DEFAULT 0,
  skipped_count integer NOT NULL DEFAULT 0,
  field_map jsonb DEFAULT '{}'::jsonb,    -- {detected_header: bc_field}
  errors jsonb DEFAULT '[]'::jsonb,       -- [{row_idx, reason}]
  status text NOT NULL DEFAULT 'completed', -- preview | committed | failed
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS business_imports_business_idx
  ON business_imports (business_id, created_at DESC);

ALTER TABLE business_imports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "business_imports: owner read"
  ON business_imports FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM businesses WHERE id = business_imports.business_id AND owner_id = auth.uid())
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  );

CREATE POLICY "business_imports: service role insert"
  ON business_imports FOR INSERT
  WITH CHECK (true);

GRANT SELECT ON business_imports TO authenticated;
