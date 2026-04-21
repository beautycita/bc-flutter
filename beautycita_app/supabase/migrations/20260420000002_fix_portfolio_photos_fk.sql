-- =============================================================================
-- Migration: 20260420000002_fix_portfolio_photos_fk.sql
-- Description: portfolio_photos.business_id FK incorrectly references
-- auth.users(id) instead of public.businesses(id). PostgREST cannot resolve
-- the implicit join `portfolio_photos!business_id` to public.businesses,
-- so feed-public + salon-page + business CRUD all log:
--   "Could not find a relationship between 'portfolio_photos' and
--    'businesses' in the schema cache"
-- The original migration 20260309000000 modeled it as user-owned media; later
-- code expects salon-owned. portfolio_photos has 0 rows on prod, swap is safe.
-- =============================================================================

ALTER TABLE public.portfolio_photos
  DROP CONSTRAINT IF EXISTS portfolio_photos_business_id_fkey;

ALTER TABLE public.portfolio_photos
  ADD CONSTRAINT portfolio_photos_business_id_fkey
  FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

-- Force PostgREST to rebuild its schema cache so the new relationship is
-- discoverable to embed queries (e.g. `select=*,business:businesses(*)`).
NOTIFY pgrst, 'reload schema';
