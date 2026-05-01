-- Down migration for admin salon-action RPCs.

DROP FUNCTION IF EXISTS public.admin_salon_financial_summary(uuid);
DROP FUNCTION IF EXISTS public.admin_update_salon_field(uuid, text, text);
DROP FUNCTION IF EXISTS public.admin_reset_salon_onboarding(uuid);
DROP FUNCTION IF EXISTS public.admin_set_salon_verified(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_set_salon_active(uuid, boolean, text);
DROP FUNCTION IF EXISTS public.admin_set_salon_tier(uuid, int);

DROP INDEX IF EXISTS public.idx_businesses_suspended_at_partial;

ALTER TABLE public.businesses
  DROP COLUMN IF EXISTS suspended_reason,
  DROP COLUMN IF EXISTS suspended_by,
  DROP COLUMN IF EXISTS suspended_at;
