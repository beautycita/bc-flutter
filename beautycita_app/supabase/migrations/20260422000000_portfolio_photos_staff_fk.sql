-- =============================================================================
-- Migration: 20260422000000_portfolio_photos_staff_fk.sql
-- Description: Add missing FK portfolio_photos.staff_id → staff.id.
-- Without it, PostgREST refuses to resolve embedded selects like
-- `.select("... staff(id, first_name)")` that feed-public uses — every
-- feed request logged: "Could not find a relationship between
-- 'portfolio_photos' and 'staff' in the schema cache". Column already
-- exists, values are clean (0 orphans verified), adding the constraint
-- is a pure cache fix.
--
-- ON DELETE SET NULL so removing a stylist doesn't nuke their historical
-- work from the salon portfolio (photos survive with a null staff_id).
-- =============================================================================

ALTER TABLE public.portfolio_photos
  ADD CONSTRAINT portfolio_photos_staff_id_fkey
  FOREIGN KEY (staff_id) REFERENCES public.staff(id) ON DELETE SET NULL;

-- Ask PostgREST to reload schema cache so the new relationship is available
-- without a container restart.
NOTIFY pgrst, 'reload schema';
