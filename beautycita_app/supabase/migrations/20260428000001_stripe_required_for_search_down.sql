-- Reverse 20260428000001: restore the loose Tier-1 visibility model.
-- Order matters — restore old function bodies BEFORE dropping columns
-- they reference.

-- Restore old auto_approve_business (promotion-only, no Stripe gate).
CREATE OR REPLACE FUNCTION public.auto_approve_business()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.is_verified = true THEN
    RETURN NEW;
  END IF;

  IF NEW.onboarding_complete = true THEN
    NEW.is_verified := true;

    UPDATE public.profiles
    SET role = 'stylist'
    WHERE id = NEW.owner_id
      AND role NOT IN ('admin', 'superadmin', 'stylist');
  END IF;

  RETURN NEW;
END;
$$;

-- Restore old trigger column lists.
DROP TRIGGER IF EXISTS businesses_revoke_verification ON public.businesses;
CREATE TRIGGER businesses_revoke_verification
  BEFORE UPDATE OF rfc, onboarding_complete, banking_complete, id_verification_status
  ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.revoke_verification_on_requirement_loss();

DROP TRIGGER IF EXISTS businesses_recompute_tier ON public.businesses;
CREATE TRIGGER businesses_recompute_tier
  BEFORE UPDATE OF is_active, is_verified, onboarding_complete, banking_complete
  ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.trg_recompute_tier_on_biz();

-- Restore old RPC bodies (no is_verified filter).
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
    AND (p_query IS NULL OR b.name ILIKE '%' || p_query || '%')
    AND (p_category IS NULL OR p_category = ANY(b.service_categories))
    AND (p_city IS NULL OR b.city ILIKE p_city)
  ORDER BY b.average_rating DESC NULLS LAST, b.total_reviews DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Now safe to drop the column + its lock trigger.
DROP TRIGGER IF EXISTS businesses_lock_stripe_bypass ON public.businesses;
DROP FUNCTION IF EXISTS public.lock_stripe_bypass();
ALTER TABLE public.businesses DROP COLUMN IF EXISTS stripe_bypass;
