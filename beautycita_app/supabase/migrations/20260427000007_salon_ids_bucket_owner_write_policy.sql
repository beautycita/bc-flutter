-- salon-ids bucket: allow business owners to UPLOAD their own ID photos.
--
-- BC found "Error al subir archivo" when adding bank account → uploading
-- ID front/back. Root cause: the bucket had two SELECT policies but ZERO
-- INSERT/UPDATE/DELETE policies, so RLS silently blocked every upload.
-- The existing SELECT policy was also malformed — it compared
-- (businesses.id)::text to (storage.foldername(businesses.name))[1],
-- which parses the salon's display name not the storage object path.
--
-- Fix:
--   * Replace the SELECT policy with one that parses the OBJECT name and
--     pins to the owner's business id.
--   * Add INSERT/UPDATE/DELETE policies for the owner.
--   * Admin SELECT policy stays.
--
-- Object path convention (from banking_setup_screen.dart):
--     salon-ids/{business_id}/id_front.jpg
--     salon-ids/{business_id}/id_back.jpg
-- (storage.foldername returns array starting at index 1 in Postgres; the
--  first segment is the literal "salon-ids", second is the business id.)

DROP POLICY IF EXISTS "Salon owner reads own IDs" ON storage.objects;

CREATE POLICY "salon-ids: owner read own"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND (
      auth.uid() IN (
        SELECT b.owner_id FROM public.businesses b
         WHERE b.id::text = (storage.foldername(name))[2]
      )
      OR auth.uid() IN (
        SELECT id FROM public.profiles WHERE role IN ('admin','superadmin')
      )
    )
  );

CREATE POLICY "salon-ids: owner insert own"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'salon-ids'
    AND auth.uid() IN (
      SELECT b.owner_id FROM public.businesses b
       WHERE b.id::text = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "salon-ids: owner update own"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND auth.uid() IN (
      SELECT b.owner_id FROM public.businesses b
       WHERE b.id::text = (storage.foldername(name))[2]
    )
  )
  WITH CHECK (
    bucket_id = 'salon-ids'
    AND auth.uid() IN (
      SELECT b.owner_id FROM public.businesses b
       WHERE b.id::text = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "salon-ids: owner delete own"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND auth.uid() IN (
      SELECT b.owner_id FROM public.businesses b
       WHERE b.id::text = (storage.foldername(name))[2]
    )
  );
