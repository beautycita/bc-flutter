-- =============================================================================
-- Salon Banking Collection — CLABE, beneficiary, photo ID, verification
-- =============================================================================

-- New columns on businesses
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS clabe text,
  ADD COLUMN IF NOT EXISTS bank_name text,
  ADD COLUMN IF NOT EXISTS beneficiary_name text,
  ADD COLUMN IF NOT EXISTS id_front_url text,
  ADD COLUMN IF NOT EXISTS id_back_url text,
  ADD COLUMN IF NOT EXISTS id_verification_status text NOT NULL DEFAULT 'none'
    CHECK (id_verification_status IN ('none', 'pending', 'verified', 'rejected')),
  ADD COLUMN IF NOT EXISTS id_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS banking_complete boolean NOT NULL DEFAULT false;

-- CLABE must be exactly 18 digits when provided
ALTER TABLE businesses
  ADD CONSTRAINT clabe_format CHECK (clabe IS NULL OR clabe ~ '^\d{18}$');

-- Index for filtering salons by banking status (admin dashboard, booking queries)
CREATE INDEX IF NOT EXISTS idx_businesses_banking_complete ON businesses (banking_complete);

-- Admin accounts (BC's 3 test accounts) get banking_complete = true
UPDATE businesses SET banking_complete = true
WHERE owner_id IN (
  SELECT id FROM profiles WHERE role = 'admin'
);

-- Private storage bucket for ID documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('salon-ids', 'salon-ids', false)
ON CONFLICT (id) DO NOTHING;

-- RLS: salon owner can upload to their business folder, admin can read all
CREATE POLICY "Salon owner uploads own IDs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'salon-ids'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] IN (
      SELECT id::text FROM businesses WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Salon owner reads own IDs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'salon-ids'
    AND (
      auth.uid() IN (SELECT owner_id FROM businesses WHERE id::text = (storage.foldername(name))[1])
      OR auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin')
    )
  );

CREATE POLICY "Admin reads all salon IDs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'salon-ids'
    AND auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin')
  );
