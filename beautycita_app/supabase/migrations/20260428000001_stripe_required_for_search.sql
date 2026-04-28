-- =============================================================================
-- Search visibility now requires Stripe Connect onboarding (or admin bypass).
--
-- Before today: a salon with services + schedule was Tier-1 visible
-- regardless of Stripe state. The thinking was "discovery is free,
-- payment problems show at checkout." BC reversed that call 2026-04-28:
-- a salon that can't take payments shouldn't appear in search at all.
--
-- This migration:
--   1. Adds `stripe_bypass boolean` to businesses — superadmin override
--      so test/back-office salons can be visible without finishing Stripe.
--   2. Locks the column so owners can't self-promote.
--   3. Rewrites auto_approve_business to be promotion-AND-demotion capable
--      and to require ((charges AND payouts) OR stripe_bypass) on top of
--      onboarding_complete.
--   4. Adds Stripe state columns to revoke_verification_on_requirement_loss
--      and businesses_recompute_tier trigger column lists so a Stripe
--      drop demotes the salon out of search.
--   5. Tightens nearby_businesses + search_businesses RPCs to require
--      `is_verified = true`.
--   6. Backfills existing currently-visible salons with stripe_bypass=true
--      so we don't yank visibility from anyone tonight; superadmin can
--      revoke per-row later.
-- =============================================================================

-- 1. Column ----------------------------------------------------------------
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS stripe_bypass boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.businesses.stripe_bypass IS
  'Superadmin override — when true, the salon is treated as if Stripe Connect were complete. Used for test salons and grandfathered rows.';

-- 2. Write protection trigger ---------------------------------------------
-- Only service_role (edge functions, admin RPCs) and superadmin profiles
-- may flip stripe_bypass. Salon-owner UPDATEs reset it back to OLD.
CREATE OR REPLACE FUNCTION public.lock_stripe_bypass()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text;
  v_is_superadmin boolean := false;
BEGIN
  -- DB superusers (migrations, ops scripts) bypass entirely.
  IF current_user IN ('postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  -- service_role bypasses (edge functions running as the platform).
  v_role := current_setting('request.jwt.claim.role', true);
  IF v_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Superadmin profile may also flip it.
  IF auth.uid() IS NOT NULL THEN
    SELECT (role IN ('admin','superadmin')) INTO v_is_superadmin
      FROM public.profiles WHERE id = auth.uid();
    IF v_is_superadmin THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Anyone else: revert any change to stripe_bypass.
  IF NEW.stripe_bypass IS DISTINCT FROM OLD.stripe_bypass THEN
    NEW.stripe_bypass := OLD.stripe_bypass;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS businesses_lock_stripe_bypass ON public.businesses;
CREATE TRIGGER businesses_lock_stripe_bypass
  BEFORE UPDATE OF stripe_bypass ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.lock_stripe_bypass();

-- 3. Promotion + demotion: rewrite auto_approve_business -----------------
-- The original function is owned by supabase_admin (Supabase dashboard
-- migrations historically created it as that role). CREATE OR REPLACE
-- requires ownership. Since `postgres` is not a member of supabase_admin
-- in this cluster, the reassignment must be performed out-of-band:
--   docker exec supabase-db psql -U supabase_admin -d postgres \
--     -c "ALTER FUNCTION public.auto_approve_business() OWNER TO postgres;"
-- The migration runner (postgres) cannot do this itself. The line below
-- is a no-op when ownership has already been transferred and is left as
-- a marker; if it fails, run the out-of-band command above first.
DO $$
BEGIN
  IF (SELECT proowner::regrole::text FROM pg_proc
        WHERE proname='auto_approve_business' AND pronamespace='public'::regnamespace) <> 'postgres' THEN
    RAISE EXCEPTION 'Run as supabase_admin: ALTER FUNCTION public.auto_approve_business() OWNER TO postgres;';
  END IF;
END $$;
CREATE OR REPLACE FUNCTION public.auto_approve_business()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_eligible boolean;
BEGIN
  -- The verification gate: onboarding_complete AND
  --   ((Stripe charges + payouts both enabled) OR superadmin bypass).
  v_eligible :=
    COALESCE(NEW.onboarding_complete, false) = true
    AND (
      COALESCE(NEW.stripe_bypass, false) = true
      OR (
        COALESCE(NEW.stripe_charges_enabled, false) = true
        AND COALESCE(NEW.stripe_payouts_enabled, false) = true
      )
    );

  NEW.is_verified := v_eligible;

  -- Profile role promotion only on first transition to verified, and only
  -- when role isn't already a privileged role we shouldn't downgrade.
  IF v_eligible AND (TG_OP = 'INSERT' OR COALESCE(OLD.is_verified, false) = false) THEN
    UPDATE public.profiles
       SET role = 'stylist'
     WHERE id = NEW.owner_id
       AND role NOT IN ('admin', 'superadmin', 'stylist');
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Demote when requirements drop ---------------------------------------
-- The existing revoke_verification_on_requirement_loss trigger already
-- handles RFC / banking / id_verification drops. Extend its column list
-- so Stripe state changes also fire it.
DROP TRIGGER IF EXISTS businesses_revoke_verification ON public.businesses;
CREATE TRIGGER businesses_revoke_verification
  BEFORE UPDATE OF rfc, onboarding_complete, banking_complete,
                   id_verification_status,
                   stripe_charges_enabled, stripe_payouts_enabled,
                   stripe_bypass
  ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.revoke_verification_on_requirement_loss();

-- Tier recomputation: include Stripe state changes so tier reflects them.
DROP TRIGGER IF EXISTS businesses_recompute_tier ON public.businesses;
CREATE TRIGGER businesses_recompute_tier
  BEFORE UPDATE OF is_active, is_verified, onboarding_complete,
                   banking_complete,
                   stripe_charges_enabled, stripe_payouts_enabled,
                   stripe_bypass
  ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.trg_recompute_tier_on_biz();

-- 5. RPCs gate on is_verified --------------------------------------------
CREATE OR REPLACE FUNCTION public.nearby_businesses(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 10.0,
  p_category text DEFAULT NULL::text,
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  id uuid, name text, phone text, whatsapp text, address text,
  city text, lat double precision, lng double precision, photo_url text,
  average_rating numeric, total_reviews integer, business_category text,
  service_categories text[], hours jsonb, is_verified boolean,
  tier integer, accept_walkins boolean, distance_km double precision
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    b.id, b.name, b.phone, b.whatsapp, b.address, b.city, b.lat, b.lng,
    b.photo_url, b.average_rating, b.total_reviews, b.business_category,
    b.service_categories, b.hours, b.is_verified, b.tier, b.accept_walkins,
    round((st_distance(
      b.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    ) / 1000.0)::numeric, 2)::double precision AS distance_km
  FROM public.businesses b
  WHERE b.is_active = true
    AND b.is_verified = true
    AND b.location IS NOT NULL
    AND st_dwithin(
      b.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
    AND (p_category IS NULL OR p_category = ANY(b.service_categories))
  ORDER BY distance_km ASC
  LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION public.search_businesses(
  p_query text DEFAULT NULL::text,
  p_category text DEFAULT NULL::text,
  p_city text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid, name text, phone text, whatsapp text, address text,
  city text, lat double precision, lng double precision, photo_url text,
  average_rating numeric, total_reviews integer, business_category text,
  service_categories text[], hours jsonb, is_verified boolean,
  tier integer, accept_walkins boolean
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    b.id, b.name, b.phone, b.whatsapp, b.address, b.city, b.lat, b.lng,
    b.photo_url, b.average_rating, b.total_reviews, b.business_category,
    b.service_categories, b.hours, b.is_verified, b.tier, b.accept_walkins
  FROM public.businesses b
  WHERE b.is_active = true
    AND b.is_verified = true
    AND (p_query IS NULL OR b.name ILIKE '%' || p_query || '%')
    AND (p_category IS NULL OR p_category = ANY(b.service_categories))
    AND (p_city IS NULL OR b.city ILIKE p_city)
  ORDER BY b.average_rating DESC NULLS LAST, b.total_reviews DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- 6. Backfill: grandfather existing visible salons -----------------------
-- Anyone already is_verified=true who doesn't satisfy the new gate gets
-- bypass so today's search results don't go dark. Covers all four
-- mid-states (charges-only, payouts-only, neither, etc.). Superadmin
-- can flip the bypass off per-row later if desired.
UPDATE public.businesses
   SET stripe_bypass = true
 WHERE is_verified = true
   AND NOT stripe_bypass
   AND NOT (
     COALESCE(stripe_charges_enabled, false) = true
     AND COALESCE(stripe_payouts_enabled, false) = true
   );

-- 7. Invariant check ------------------------------------------------------
-- After this migration, every is_verified row must satisfy the gate.
DO $$
DECLARE v_bad int;
BEGIN
  SELECT count(*) INTO v_bad
    FROM public.businesses
   WHERE is_verified = true
     AND NOT (
       COALESCE(stripe_bypass, false) = true
       OR (COALESCE(stripe_charges_enabled, false) = true
           AND COALESCE(stripe_payouts_enabled, false) = true)
     );
  IF v_bad > 0 THEN
    RAISE EXCEPTION 'invariant violated: % is_verified rows do not satisfy gate', v_bad;
  END IF;
END $$;
