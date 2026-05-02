-- Reverse 20260502000001
-- Restores the original prevent_role_change body and drops the promote
-- triggers. Does NOT downgrade stylist roles back to customer (data
-- preservation: those backfilled rows are correct now).

DROP TRIGGER IF EXISTS businesses_promote_owner_role ON public.businesses;
DROP TRIGGER IF EXISTS businesses_promote_owner_role_on_change ON public.businesses;
DROP FUNCTION IF EXISTS public.promote_business_owner_role();

-- Restoring NOT NULL would fail on existing system-logged rows; left as-is.

CREATE OR REPLACE FUNCTION public.prevent_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
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
