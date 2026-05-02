-- =============================================================================
-- 20260502000001 — promote business owner role to stylist
-- =============================================================================
-- Bug: a profile that owns a business can be left at role='customer' because
-- prevent_role_change() silently reverts any role UPDATE whose auth.uid() is
-- not a superadmin. service-role calls (edge functions, server-side jobs)
-- have auth.uid()=NULL so their role flips were swallowed. Result: business
-- panel shows on mobile (gated on owner_id match) but web hides it (gated on
-- profiles.role). Found while testing "Salon Studio Kriket".
--
-- Fix:
--   1. Loosen prevent_role_change so service_role / supabase_admin / postgres
--      callers can change role. PostgREST authenticated/anon users are still
--      blocked.
--   2. Add AFTER INSERT trigger on businesses that promotes owner from
--      customer -> stylist. Higher roles (admin/superadmin/rp/ops_admin)
--      are left untouched.
--   3. Backfill any drifted owners.
-- =============================================================================

-- 1. Loosen prevent_role_change
CREATE OR REPLACE FUNCTION public.prevent_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- Service / admin DB roles always allowed: edge functions and internal
    -- triggers (e.g. promote_business_owner_role below) need to land role
    -- changes without the calling user being a superadmin.
    IF current_user IN ('service_role', 'supabase_admin', 'postgres') THEN
      RETURN NEW;
    END IF;

    -- Otherwise: only superadmin in the application sense.
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'superadmin'
    ) THEN
      NEW.role := OLD.role;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Promote business owner trigger
CREATE OR REPLACE FUNCTION public.promote_business_owner_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.owner_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.profiles
     SET role = 'stylist'
   WHERE id = NEW.owner_id
     AND role = 'customer';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS businesses_promote_owner_role ON public.businesses;
CREATE TRIGGER businesses_promote_owner_role
  AFTER INSERT ON public.businesses
  FOR EACH ROW
  EXECUTE FUNCTION public.promote_business_owner_role();

-- Also handle owner_id reassignment (rare, but covered).
DROP TRIGGER IF EXISTS businesses_promote_owner_role_on_change ON public.businesses;
CREATE TRIGGER businesses_promote_owner_role_on_change
  AFTER UPDATE OF owner_id ON public.businesses
  FOR EACH ROW
  WHEN (NEW.owner_id IS DISTINCT FROM OLD.owner_id)
  EXECUTE FUNCTION public.promote_business_owner_role();

-- 3. Drop the NOT NULL on audit_log.admin_id so log_role_change() can record
--    system-driven role changes (auth.uid() is NULL outside a request).
--    The trigger's source comment already assumed this column was nullable;
--    this aligns the schema with the trigger intent.
ALTER TABLE public.audit_log ALTER COLUMN admin_id DROP NOT NULL;

-- 4. Backfill drifted owners
UPDATE public.profiles
   SET role = 'stylist'
 WHERE role = 'customer'
   AND id IN (
     SELECT DISTINCT owner_id
       FROM public.businesses
      WHERE owner_id IS NOT NULL
   );
