-- =============================================================================
-- Migration: 20260421000005_tier_autocompute_and_curate_ranking.sql
-- Description: Make businesses.tier earn its keep. Was dead data — not
-- filtered, not sorted, only set by admin and nothing read it. Per BC
-- decision 2026-04-21, wire it into curate ranking.
--
-- Three tiers (matches launch_strategy memory — discovery → bookable → revenue):
--   1 = Discovery  : not yet ready to transact (missing banking or onboarding)
--   2 = Bookable   : onboarded + verified + banking complete (ready for traffic)
--   3 = Revenue    : Tier 2 + ≥5 completed appointments in last 60 days (proven)
--
-- Auto-computed — admin can still override manually via the detail screen,
-- but next appointment-status change recomputes unless we add an override flag.
-- For now keep it fully auto. If BC wants a "pinned tier 3" override later,
-- add a tier_override column and skip compute when set.
-- =============================================================================

-- ── 1. The compute function ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.compute_business_tier(p_business_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_biz RECORD;
  v_completed_count integer;
BEGIN
  SELECT is_active, is_verified, onboarding_complete, banking_complete
  INTO v_biz
  FROM public.businesses
  WHERE id = p_business_id;

  IF NOT FOUND THEN
    RETURN 1;
  END IF;

  -- Tier 1 if not fully onboarded + bankable
  IF NOT (v_biz.is_active AND v_biz.is_verified
           AND v_biz.onboarding_complete AND v_biz.banking_complete) THEN
    RETURN 1;
  END IF;

  -- Tier 3 if has ≥5 completed appts in last 60 days
  SELECT count(*)::int INTO v_completed_count
  FROM public.appointments
  WHERE business_id = p_business_id
    AND status = 'completed'
    AND starts_at > now() - interval '60 days';

  IF v_completed_count >= 5 THEN
    RETURN 3;
  END IF;

  -- Default to Tier 2 (ready, not yet proven)
  RETURN 2;
END;
$$;

COMMENT ON FUNCTION public.compute_business_tier(uuid) IS
  'Computes tier from state + activity. 1=discovery, 2=bookable, 3=revenue. '
  'Read by triggers on businesses + appointments. See '
  '20260421000005_tier_autocompute_and_curate_ranking.sql for semantics.';

-- ── 2. Trigger on appointments: any status change recomputes business tier
CREATE OR REPLACE FUNCTION public.trg_recompute_tier_on_appt()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_tier int;
BEGIN
  v_tier := public.compute_business_tier(NEW.business_id);
  UPDATE public.businesses SET tier = v_tier
  WHERE id = NEW.business_id AND tier IS DISTINCT FROM v_tier;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS appointments_recompute_biz_tier ON public.appointments;
CREATE TRIGGER appointments_recompute_biz_tier
  AFTER INSERT OR UPDATE OF status ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_recompute_tier_on_appt();

-- ── 3. Trigger on businesses: when onboarding/banking/verified flips, recompute
CREATE OR REPLACE FUNCTION public.trg_recompute_tier_on_biz()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only recompute when one of the gate flags actually changed
  IF OLD.is_active IS DISTINCT FROM NEW.is_active
     OR OLD.is_verified IS DISTINCT FROM NEW.is_verified
     OR OLD.onboarding_complete IS DISTINCT FROM NEW.onboarding_complete
     OR OLD.banking_complete IS DISTINCT FROM NEW.banking_complete
  THEN
    NEW.tier := public.compute_business_tier(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS businesses_recompute_tier ON public.businesses;
CREATE TRIGGER businesses_recompute_tier
  BEFORE UPDATE OF is_active, is_verified, onboarding_complete, banking_complete
  ON public.businesses
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_recompute_tier_on_biz();

-- ── 4. Backfill existing rows ───────────────────────────────────────────
UPDATE public.businesses b
SET tier = public.compute_business_tier(b.id);

-- ── 5. Rebuild curate_candidates to ORDER BY tier DESC first ────────────
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
  ORDER BY rs.business_tier DESC NULLS LAST,   -- NEW: tier-first ranking
           rs.distance_m,
           rs.slot_start
  LIMIT 50;
$$;

COMMENT ON FUNCTION public.curate_candidates IS
  'Discover bookable salons + slots. Gates: is_active, is_verified, '
  'onboarding_complete, banking_complete. Ranked by tier DESC (auto-computed '
  '1=discovery/2=bookable/3=revenue — see compute_business_tier), then distance, '
  'then slot_start. Diversity via ROW_NUMBER PARTITION BY staff_id.';
