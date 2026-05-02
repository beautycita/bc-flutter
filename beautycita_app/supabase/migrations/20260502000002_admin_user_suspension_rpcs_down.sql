-- Reverse 20260502000002
DROP FUNCTION IF EXISTS public.admin_suspend_for_tos_violation(uuid, text);
DROP FUNCTION IF EXISTS public.admin_set_salon_active_v2(uuid, boolean, text, text);
DROP FUNCTION IF EXISTS public.admin_set_user_status(uuid, text, text, text);

DROP INDEX IF EXISTS idx_profiles_suspended_at_partial;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS suspension_kind,
  DROP COLUMN IF EXISTS suspended_reason,
  DROP COLUMN IF EXISTS suspended_by,
  DROP COLUMN IF EXISTS suspended_at;

ALTER TABLE public.businesses
  DROP COLUMN IF EXISTS suspension_kind;
