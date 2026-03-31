-- =============================================================================
-- Migration: Enforce is_verified on all customer-facing business queries,
--            and restrict booking availability to owner + stylist positions only.
-- No unverified (pending admin review) salon should appear to customers.
-- Non-stylist staff (receptionists, managers, assistants) must never appear
-- in booking flows.
-- =============================================================================

-- Drop old overload without p_business_id (superseded by version with default param)
DROP FUNCTION IF EXISTS public.curate_candidates(
  text, double precision, double precision, integer, timestamptz, timestamptz
);

-- Recreate curate_candidates with is_verified + position IN ('owner','stylist') filters
CREATE OR REPLACE FUNCTION public.curate_candidates(
  p_service_type   text,
  p_lat            double precision,
  p_lng            double precision,
  p_radius_meters  integer,
  p_window_start   timestamptz,
  p_window_end     timestamptz,
  p_business_id    uuid DEFAULT NULL
)
RETURNS TABLE (
  business_id      uuid,
  business_name    text,
  business_photo   text,
  business_address text,
  business_lat     double precision,
  business_lng     double precision,
  business_whatsapp text,
  business_rating  numeric,
  business_reviews integer,
  cancellation_hours integer,
  deposit_required boolean,
  auto_confirm     boolean,
  accept_walkins   boolean,
  service_id       uuid,
  service_name     text,
  service_price    numeric,
  duration_minutes integer,
  buffer_minutes   integer,
  staff_id         uuid,
  staff_name       text,
  staff_avatar     text,
  experience_years integer,
  staff_rating     numeric,
  staff_reviews    integer,
  effective_price  numeric,
  effective_duration integer,
  distance_m       double precision,
  slot_start       timestamptz,
  slot_end         timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH service_match AS (
    SELECT
      b.id            AS business_id,
      b.name          AS business_name,
      b.photo_url     AS business_photo,
      b.address       AS business_address,
      b.lat           AS business_lat,
      b.lng           AS business_lng,
      b.whatsapp      AS business_whatsapp,
      b.average_rating AS business_rating,
      b.total_reviews  AS business_reviews,
      b.cancellation_hours,
      b.deposit_required,
      b.auto_confirm,
      b.accept_walkins,
      s.id            AS service_id,
      s.name          AS service_name,
      s.price         AS service_price,
      s.duration_minutes,
      s.buffer_minutes,
      st.id           AS staff_id,
      st.first_name || ' ' || coalesce(left(st.last_name, 1) || '.', '') AS staff_name,
      st.avatar_url   AS staff_avatar,
      st.experience_years,
      st.average_rating AS staff_rating,
      st.total_reviews  AS staff_reviews,
      coalesce(ss.custom_price, s.price)       AS effective_price,
      coalesce(ss.custom_duration, s.duration_minutes) AS effective_duration,
      ST_Distance(
        b.location,
        ST_MakePoint(p_lng, p_lat)::geography
      ) AS distance_m
    FROM businesses b
    JOIN services s          ON s.business_id = b.id
    JOIN staff_services ss   ON ss.service_id = s.id
    JOIN staff st            ON st.id = ss.staff_id
    WHERE s.service_type = p_service_type
      AND s.is_active   = true
      AND st.is_active  = true
      AND st.accept_online_booking = true
      AND st.position IN ('owner', 'stylist')   -- Only booking-eligible positions
      AND b.is_active   = true
      AND b.is_verified  = true   -- Only admin-approved businesses
      AND b.onboarding_complete = true
      AND (p_business_id IS NULL OR b.id = p_business_id)
      AND ST_DWithin(
        b.location,
        ST_MakePoint(p_lng, p_lat)::geography,
        p_radius_meters
      )
  )
  SELECT
    sm.business_id,
    sm.business_name,
    sm.business_photo,
    sm.business_address,
    sm.business_lat,
    sm.business_lng,
    sm.business_whatsapp,
    sm.business_rating,
    sm.business_reviews,
    sm.cancellation_hours,
    sm.deposit_required,
    sm.auto_confirm,
    sm.accept_walkins,
    sm.service_id,
    sm.service_name,
    sm.service_price,
    sm.duration_minutes,
    sm.buffer_minutes,
    sm.staff_id,
    sm.staff_name,
    sm.staff_avatar,
    sm.experience_years,
    sm.staff_rating,
    sm.staff_reviews,
    sm.effective_price,
    sm.effective_duration,
    sm.distance_m,
    avail.slot_start,
    avail.slot_start + (sm.effective_duration || ' minutes')::interval AS slot_end
  FROM service_match sm
  CROSS JOIN LATERAL public.find_available_slots(
    sm.staff_id,
    sm.effective_duration,
    p_window_start,
    p_window_end
  ) avail
  ORDER BY sm.distance_m, avail.slot_start
  LIMIT 50;
$$;

COMMENT ON FUNCTION public.curate_candidates(text, double precision, double precision, integer, timestamptz, timestamptz, uuid) IS
  'Finds candidate businesses/staff/slots for the curate-results engine. '
  'Only returns staff with position IN (owner, stylist) — receptionists, '
  'managers, and assistants are never shown to clients in booking flows. '
  'INNER JOIN on staff_services ensures only staff with assigned services appear. '
  'Optional p_business_id locks results to a specific business (Cita Express walk-in).';
