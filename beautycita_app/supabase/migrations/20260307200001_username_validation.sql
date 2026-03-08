-- Server-side username validation trigger.
-- Blocks reserved words, impersonation attempts, and profanity at the DB level.
-- This is the ultimate defense — even direct SQL bypassing the app is caught.

CREATE OR REPLACE FUNCTION public.validate_username()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  normalized text;
  reserved_words text[] := ARRAY[
    -- Platform identity
    'beautycita', 'beautycit', 'beauticita', 'beauticit',
    'bcita', 'bcapp',
    -- Roles & authority
    'admin', 'administrador', 'administrator',
    'superadmin', 'superadministrador',
    'moderador', 'moderator',
    'soporte', 'support',
    'sistema', 'system',
    'oficial', 'official',
    'verificado', 'verified',
    'staff', 'empleado',
    'helpdesk',
    -- Team
    'eros',
    -- Technical
    'root', 'sudo', 'null', 'undefined', 'anonymous',
    'bot', 'robot',
    'security', 'seguridad'
  ];
  profanity text[] := ARRAY[
    'puta', 'puto', 'pendejo', 'pendeja', 'chinga', 'chingada',
    'verga', 'culero', 'culera', 'cabron', 'cabrona', 'mamada',
    'joto', 'maricon', 'marica', 'mierda', 'pinche',
    'zorra', 'prostituta',
    'fuck', 'shit', 'bitch', 'asshole', 'nigger', 'nigga',
    'faggot', 'retard', 'cunt', 'whore', 'slut'
  ];
  word text;
BEGIN
  IF NEW.username IS NULL THEN
    RETURN NEW;
  END IF;

  -- Normalize: lowercase, strip diacritics, decode leet speak
  normalized := lower(NEW.username);
  normalized := translate(normalized,
    'áàäâãåéèëêíìïîóòöôõúùüûñç',
    'aaaaaaeeeeiiiioooooouuuunc');
  normalized := translate(normalized,
    '013457@$!8',
    'oieast asib');
  -- Collapse repeated chars (3+ of same char → 1)
  normalized := regexp_replace(normalized, '(.)\1{2,}', '\1', 'g');

  -- Check reserved words
  FOREACH word IN ARRAY reserved_words LOOP
    IF normalized LIKE '%' || word || '%' THEN
      RAISE EXCEPTION 'Username contains reserved word: %', word
        USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;

  -- Check profanity
  FOREACH word IN ARRAY profanity LOOP
    IF normalized LIKE '%' || word || '%' THEN
      RAISE EXCEPTION 'Username contains prohibited content'
        USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;

  -- No all-numeric usernames
  IF NEW.username ~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'Username cannot be all numbers'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

-- Attach trigger to profiles table
DROP TRIGGER IF EXISTS trg_validate_username ON public.profiles;
CREATE TRIGGER trg_validate_username
  BEFORE INSERT OR UPDATE OF username ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_username();

COMMENT ON FUNCTION public.validate_username() IS
  'Validates usernames: blocks reserved words (admin, support, beautycita, etc.), '
  'profanity (ES+EN), all-numeric names, and leet speak / diacritic evasion attempts.';
