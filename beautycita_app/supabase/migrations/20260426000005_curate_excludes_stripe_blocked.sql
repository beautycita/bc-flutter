-- =============================================================================
-- curate_candidates: exclude stripe_charges_enabled=false salons
-- =============================================================================
-- Policy (Kriket 2026-04-26):
--   stripe_charges_enabled=false ⇒ salon CANNOT process payments at all ⇒
--   they should NOT appear in customer-facing search results, regardless of
--   cash trust status. Cash-eligibility has 0 effect on visibility — only
--   on which payment methods render in the booking sheet.
--
-- Adds `AND b.stripe_charges_enabled = true` to the WHERE clause of the
-- service_match CTE in curate_candidates.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.curate_candidates(
  p_service_type text, p_lat double precision, p_lng double precision,
  p_radius_meters integer, p_window_start timestamp with time zone,
  p_window_end timestamp with time zone, p_business_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE(
  business_id uuid, business_name text, business_photo text, business_address text,
  business_lat double precision, business_lng double precision, business_whatsapp text,
  business_rating numeric, business_reviews integer, cancellation_hours integer,
  deposit_required boolean, auto_confirm boolean, accept_walkins boolean,
  service_id uuid, service_name text, service_price numeric,
  duration_minutes integer, buffer_minutes integer,
  staff_id uuid, staff_name text, staff_avatar text,
  experience_years integer, staff_rating numeric, staff_reviews integer,
  effective_price numeric, effective_duration integer,
  distance_m double precision, slot_start timestamp with time zone,
  slot_end timestamp with time zone
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
      b.tier          AS business_tier,
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
      AND st.position IN ('owner', 'stylist')
      AND b.is_active   = true
      AND b.is_verified  = true
      AND b.onboarding_complete = true
      AND b.banking_complete = true
      AND b.stripe_charges_enabled = true   -- NEW: stripe-blocked salons hidden
      AND (p_business_id IS NULL OR b.id = p_business_id)
      AND ST_DWithin(
        b.location,
        ST_MakePoint(p_lng, p_lat)::geography,
        p_radius_meters
      )
  ),
  ranked_slots AS (
    SELECT
      sm.*,
      avail.slot_start,
      avail.slot_start + (sm.effective_duration || ' minutes')::interval AS slot_end,
      ROW_NUMBER() OVER (
        PARTITION BY sm.staff_id
        ORDER BY avail.slot_start
      ) AS slot_rank
    FROM service_match sm
    CROSS JOIN LATERAL public.find_available_slots(
      sm.staff_id,
      sm.effective_duration,
      p_window_start,
      p_window_end
    ) avail
  )
  SELECT
    rs.business_id, rs.business_name, rs.business_photo,
    rs.business_address, rs.business_lat, rs.business_lng,
    rs.business_whatsapp, rs.business_rating, rs.business_reviews,
    rs.cancellation_hours, rs.deposit_required,
    rs.auto_confirm, rs.accept_walkins,
    rs.service_id, rs.service_name, rs.service_price,
    rs.duration_minutes, rs.buffer_minutes,
    rs.staff_id, rs.staff_name, rs.staff_avatar,
    rs.experience_years, rs.staff_rating, rs.staff_reviews,
    rs.effective_price, rs.effective_duration,
    rs.distance_m,
    rs.slot_start, rs.slot_end
  FROM ranked_slots rs
  WHERE rs.slot_rank <= 5
  ORDER BY rs.business_tier DESC NULLS LAST,
           rs.distance_m,
           rs.slot_start
  LIMIT 50;
$function$;

COMMENT ON FUNCTION public.curate_candidates(text, double precision, double precision, integer, timestamptz, timestamptz, uuid) IS
  'Customer search: returns only businesses with stripe_charges_enabled=true. Cash-eligibility (cash_eligible_at) has zero effect on visibility — only on which payment methods render at booking time.';
