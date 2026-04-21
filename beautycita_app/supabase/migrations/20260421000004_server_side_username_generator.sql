-- =============================================================================
-- Migration: 20260421000004_server_side_username_generator.sql
-- Description: Server-side cute-username generator + update handle_new_user
-- trigger to use it. The client-side UsernameGenerator only runs for the
-- biometric signup path. Google OAuth, WebAuthn passkey, anonymous users,
-- and any non-biometric signup fell through to the `user_<hex>` fallback
-- in the trigger — violating the "no numbers in usernames" rule
-- (feedback_usernames memory).
--
-- Word lists extracted from lib/services/username_generator.dart
-- (50 adjectives × 49 nouns = 2,450 two-word combos; three-word on collision).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_cute_username()
RETURNS text
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_adjectives text[] := ARRAY[
    'velvet','golden','coral','moonlit','sparkle','crystal','honey','cherry',
    'pearl','silk','rose','amber','jade','lavender','crimson','ivory','scarlet',
    'emerald','sapphire','ruby','opal','cosmic','dreamy','mystic','starlit',
    'twilight','radiant','shimmer','glitter','frosted','blushing','dewy',
    'luminous','enchanted','serene','ethereal','celestial','divine','precious',
    'dazzling','strawberry','blissful','whispering','dancing','singing',
    'blazing','glowing','shining','twinkling','sparkling'
  ];
  v_nouns text[] := ARRAY[
    'blonde','bee','rose','lash','glow','dream','queen','blossom','mist','curl',
    'nail','star','moon','petal','jewel','crown','butterfly','orchid','dahlia',
    'peony','lily','iris','violet','gem','tiara','goddess','swan','dove',
    'phoenix','angel','muse','diva','belle','charm','pixie','fairy','bloom',
    'aurora','luna','stella','sky','sun','flame','breeze','wave','rain',
    'shine','diamond','sapphire'
  ];
  v_candidate text;
  v_adj text;
  v_noun1 text;
  v_noun2 text;
  v_attempt int := 0;
BEGIN
  -- Try two-word first (max 20 attempts)
  WHILE v_attempt < 20 LOOP
    v_adj := v_adjectives[floor(random() * array_length(v_adjectives, 1)) + 1];
    v_noun1 := v_nouns[floor(random() * array_length(v_nouns, 1)) + 1];
    -- Capitalize noun first letter: e.g. 'strawberryBlonde'
    v_candidate := v_adj || upper(left(v_noun1, 1)) || right(v_noun1, -1);
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = v_candidate) THEN
      RETURN v_candidate;
    END IF;
    v_attempt := v_attempt + 1;
  END LOOP;

  -- Three-word on heavy collision
  v_attempt := 0;
  WHILE v_attempt < 20 LOOP
    v_adj := v_adjectives[floor(random() * array_length(v_adjectives, 1)) + 1];
    v_noun1 := v_nouns[floor(random() * array_length(v_nouns, 1)) + 1];
    v_noun2 := v_nouns[floor(random() * array_length(v_nouns, 1)) + 1];
    v_candidate := v_adj
      || upper(left(v_noun1, 1)) || right(v_noun1, -1)
      || upper(left(v_noun2, 1)) || right(v_noun2, -1);
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = v_candidate) THEN
      RETURN v_candidate;
    END IF;
    v_attempt := v_attempt + 1;
  END LOOP;

  -- Catastrophic: every combination taken. Fall back to adj+noun+timestamp-ish
  -- hex (still no numbers — uses letters via md5 slice) so we never return a
  -- username with digits per feedback_usernames rule.
  RETURN v_adj || upper(left(v_noun1, 1)) || right(v_noun1, -1)
    || upper(left(translate(md5(random()::text), '0123456789', 'abcdefghij'), 1))
    || right(translate(md5(random()::text), '0123456789', 'abcdefghij'), -1)
    ;
END;
$$;

COMMENT ON FUNCTION public.generate_cute_username() IS
  'Server-side cute username generator. Returns strawberryBlonde-style names. '
  'NO DIGITS per feedback_usernames policy. Used by handle_new_user trigger.';

-- ── Update handle_new_user to call the cute generator instead of user_<hex> ──
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data ->> 'username',
      public.generate_cute_username()
    )
  );
  RETURN NEW;
END;
$$;

-- ── Retroactively fix the 4 existing bad-format usernames on prod ──
-- Pattern: user_<8 hex chars>. These all came from the fallback path pre-fix.
UPDATE public.profiles
SET username = public.generate_cute_username()
WHERE username ~ '^user_[0-9a-f]{8}$';
