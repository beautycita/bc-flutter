-- =============================================================================
-- RQ-002: Stored XSS prevention — strip HTML tags from profiles.full_name
-- =============================================================================

-- 1. Clean existing data
UPDATE public.profiles
SET full_name = regexp_replace(full_name, '<[^>]*>', '', 'g')
WHERE full_name ~ '<';

-- 2. Trigger to strip HTML on INSERT/UPDATE
CREATE OR REPLACE FUNCTION public.sanitize_profile_fullname()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.full_name IS NOT NULL THEN
    NEW.full_name := regexp_replace(NEW.full_name, '<[^>]*>', '', 'g');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sanitize_profile_fullname ON public.profiles;

CREATE TRIGGER trg_sanitize_profile_fullname
  BEFORE INSERT OR UPDATE OF full_name ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sanitize_profile_fullname();

COMMENT ON FUNCTION public.sanitize_profile_fullname IS
  'Strips HTML tags from full_name to prevent stored XSS.';
