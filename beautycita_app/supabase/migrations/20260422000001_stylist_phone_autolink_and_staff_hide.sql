-- =============================================================================
-- Migration: 20260422000001_stylist_phone_autolink_and_staff_hide.sql
-- Description: Two portfolio-pipeline foundations.
--
-- 1. Stylist auto-link by phone (bidirectional, silent)
--    When a salon owner adds a stylist with phone P, and someone is already
--    registered on BeautyCita with verified phone P, we silently set
--    staff.user_id = profiles.id so we can push-notify the stylist for
--    upcoming appointments. Works both directions: stylist data updates OR
--    a profile's phone gets verified later. No UI. Only triggers on verified
--    phones (phone_verified_at IS NOT NULL) to avoid accidental linkage.
--
-- 2. hidden_from_staff_view column on portfolio_photos
--    Stylists can "remove" a photo from their own gallery view without
--    deleting — salon still owns the image and it stays in the salon
--    portfolio. The portfolio-upload edge function filters by this column
--    on the stylist verify response; salon-side queries ignore it.
-- =============================================================================

-- ── Part 1: Auto-link stylist phone → profile ──────────────────────────────

-- Normalize helper: strips everything except digits and leading +, lowercases.
-- Placed here (not relied on elsewhere yet) so both triggers use identical
-- comparison logic.
CREATE OR REPLACE FUNCTION public._normalize_phone(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p IS NULL OR p = '' THEN NULL
    ELSE regexp_replace(p, '[^\+\d]', '', 'g')
  END;
$$;

-- Trigger: when a staff row is inserted/updated with a phone, try to find
-- a verified profile with the same normalized phone and link it.
CREATE OR REPLACE FUNCTION public.autolink_stylist_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
  v_profile_id uuid;
BEGIN
  v_norm := _normalize_phone(NEW.phone);
  IF v_norm IS NULL OR length(v_norm) < 10 THEN
    RETURN NEW;
  END IF;

  -- Skip if staff row already has a user_id (manual override wins)
  IF NEW.user_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT p.id INTO v_profile_id
  FROM public.profiles p
  WHERE _normalize_phone(p.phone) = v_norm
    AND p.phone_verified_at IS NOT NULL
  ORDER BY p.phone_verified_at DESC
  LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    NEW.user_id := v_profile_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_autolink_stylist_profile ON public.staff;
CREATE TRIGGER trg_autolink_stylist_profile
  BEFORE INSERT OR UPDATE OF phone ON public.staff
  FOR EACH ROW EXECUTE FUNCTION public.autolink_stylist_profile();

-- Trigger: when a profile's phone becomes verified (or phone changes on an
-- already-verified profile), backfill any matching staff rows that don't
-- yet have a user_id. This is the "stylist registers BC later" path.
CREATE OR REPLACE FUNCTION public.autolink_profile_to_staff()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
  v_just_verified boolean;
  v_phone_changed_while_verified boolean;
BEGIN
  v_norm := _normalize_phone(NEW.phone);
  IF v_norm IS NULL OR length(v_norm) < 10 THEN
    RETURN NEW;
  END IF;

  v_just_verified := OLD.phone_verified_at IS NULL AND NEW.phone_verified_at IS NOT NULL;
  v_phone_changed_while_verified :=
    NEW.phone_verified_at IS NOT NULL
    AND _normalize_phone(COALESCE(OLD.phone, '')) <> v_norm;

  IF NOT v_just_verified AND NOT v_phone_changed_while_verified THEN
    RETURN NEW;
  END IF;

  UPDATE public.staff
  SET user_id = NEW.id
  WHERE user_id IS NULL
    AND _normalize_phone(phone) = v_norm;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_autolink_profile_to_staff ON public.profiles;
CREATE TRIGGER trg_autolink_profile_to_staff
  AFTER UPDATE OF phone, phone_verified_at ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.autolink_profile_to_staff();

-- One-shot backfill for existing unlinked staff rows
UPDATE public.staff s
SET user_id = p.id
FROM public.profiles p
WHERE s.user_id IS NULL
  AND _normalize_phone(s.phone) IS NOT NULL
  AND length(_normalize_phone(s.phone)) >= 10
  AND _normalize_phone(s.phone) = _normalize_phone(p.phone)
  AND p.phone_verified_at IS NOT NULL;

-- ── Part 2: Stylist-hide column on portfolio_photos ────────────────────────

ALTER TABLE public.portfolio_photos
  ADD COLUMN IF NOT EXISTS hidden_from_staff_view boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.portfolio_photos.hidden_from_staff_view IS
  'When true, hide this photo from the stylist''s own gallery view on the '
  'portfolio-upload page. The salon portfolio, feed, and public salon page '
  'continue to show the photo — the salon owns all work performed in its '
  'business. Stylists delete their own view; the photo does not leave the '
  'platform.';

-- Index only the rows that are hidden (most rows won't be)
CREATE INDEX IF NOT EXISTS idx_portfolio_photos_staff_hidden
  ON public.portfolio_photos (staff_id)
  WHERE hidden_from_staff_view = true;

NOTIFY pgrst, 'reload schema';
