-- Reverse the prefix-drop. Re-prefix storage rows + businesses URLs and
-- restore the [2]-indexed policies. (No public.is_owner_of_business rebind
-- here; v7 down already handles that helper if it exists.)

UPDATE storage.objects
   SET name = 'salon-ids/' || name
 WHERE bucket_id = 'salon-ids'
   AND name NOT LIKE 'salon-ids/%';

UPDATE public.businesses
   SET id_front_url = 'salon-ids/' || id_front_url
 WHERE id_front_url IS NOT NULL AND id_front_url NOT LIKE 'salon-ids/%';

UPDATE public.businesses
   SET id_back_url = 'salon-ids/' || id_back_url
 WHERE id_back_url IS NOT NULL AND id_back_url NOT LIKE 'salon-ids/%';

UPDATE public.businesses
   SET municipal_license_url = 'salon-ids/' || municipal_license_url
 WHERE municipal_license_url IS NOT NULL AND municipal_license_url NOT LIKE 'salon-ids/%';

DROP POLICY IF EXISTS "salon-ids: owner read own"   ON storage.objects;
DROP POLICY IF EXISTS "salon-ids: owner insert own" ON storage.objects;
DROP POLICY IF EXISTS "salon-ids: owner update own" ON storage.objects;
DROP POLICY IF EXISTS "salon-ids: owner delete own" ON storage.objects;

CREATE POLICY "salon-ids: owner read own"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND (
      EXISTS (
        SELECT 1 FROM public.businesses b
         WHERE b.id::text = (storage.foldername(objects.name))[2]
           AND b.owner_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.profiles p
         WHERE p.id = auth.uid() AND p.role IN ('admin','superadmin')
      )
    )
  );

CREATE POLICY "salon-ids: owner insert own"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[2]
         AND b.owner_id = auth.uid()
    )
  );

CREATE POLICY "salon-ids: owner update own"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[2]
         AND b.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[2]
         AND b.owner_id = auth.uid()
    )
  );

CREATE POLICY "salon-ids: owner delete own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[2]
         AND b.owner_id = auth.uid()
    )
  );
