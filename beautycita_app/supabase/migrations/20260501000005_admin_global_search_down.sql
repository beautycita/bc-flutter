DROP FUNCTION IF EXISTS public.admin_global_search(text, int);
DROP INDEX IF EXISTS public.idx_businesses_city_trgm;
DROP INDEX IF EXISTS public.idx_businesses_whatsapp_trgm;
DROP INDEX IF EXISTS public.idx_businesses_phone_trgm;
DROP INDEX IF EXISTS public.idx_businesses_name_trgm;
DROP INDEX IF EXISTS public.idx_profiles_phone_trgm;
DROP INDEX IF EXISTS public.idx_profiles_username_trgm;
DROP INDEX IF EXISTS public.idx_profiles_full_name_trgm;
-- pg_trgm extension intentionally retained (may be used by other features)
