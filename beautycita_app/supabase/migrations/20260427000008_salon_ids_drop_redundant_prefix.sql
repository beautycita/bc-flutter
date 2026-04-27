-- salon-ids bucket: settle on a single object-name convention.
--
-- Mobile code historically uploaded with a redundant 'salon-ids/' prefix:
--     salon-ids/{biz}/id_front.jpg  → (storage.foldername)[1]='salon-ids'
--                                     (storage.foldername)[2]='{biz}'
-- Bughunter (and every other bucket on this project) drops the prefix:
--     {biz}/id_front.jpg            → (storage.foldername)[1]='{biz}'
--
-- The two conventions cannot coexist under one policy. Mobile is now fixed
-- to drop the prefix (banking_setup_screen.dart, salon_onboarding_screen.dart);
-- this migration:
--   (a) renames any pre-existing prefixed rows in storage.objects to match,
--   (b) rewrites businesses.{id_front_url,id_back_url,municipal_license_url}
--       to drop the prefix so verify-salon-id can still .download() them,
--   (c) drops & recreates the policies to use (storage.foldername(name))[1].

-- (a) Rename existing prefixed objects to drop 'salon-ids/'.
UPDATE storage.objects
   SET name = regexp_replace(name, '^salon-ids/', '')
 WHERE bucket_id = 'salon-ids'
   AND name LIKE 'salon-ids/%';

-- (b) Rewrite businesses URL columns to drop the prefix.
UPDATE public.businesses
   SET id_front_url = regexp_replace(id_front_url, '^salon-ids/', '')
 WHERE id_front_url LIKE 'salon-ids/%';

UPDATE public.businesses
   SET id_back_url = regexp_replace(id_back_url, '^salon-ids/', '')
 WHERE id_back_url LIKE 'salon-ids/%';

UPDATE public.businesses
   SET municipal_license_url = regexp_replace(municipal_license_url, '^salon-ids/', '')
 WHERE municipal_license_url LIKE 'salon-ids/%';

-- (c) Recreate policies on the [1] convention.
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
         WHERE b.id::text = (storage.foldername(objects.name))[1]
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
       WHERE b.id::text = (storage.foldername(objects.name))[1]
         AND b.owner_id = auth.uid()
    )
  );

CREATE POLICY "salon-ids: owner update own"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[1]
         AND b.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[1]
         AND b.owner_id = auth.uid()
    )
  );

CREATE POLICY "salon-ids: owner delete own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'salon-ids'
    AND EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id::text = (storage.foldername(objects.name))[1]
         AND b.owner_id = auth.uid()
    )
  );
