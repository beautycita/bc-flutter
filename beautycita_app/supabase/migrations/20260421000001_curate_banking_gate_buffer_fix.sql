-- =============================================================================
-- Migration: 20260421000001_curate_banking_gate_buffer_fix.sql
-- Description: Two correctness fixes in the booking engine.
--
-- 1. Restore banking_complete gate in curate_candidates. The 20260413 diversity
--    fix recreated the function and accidentally dropped the banking_complete
--    filter that 20260403 had added. Result: salons without verified banking
--    appeared in search results (they'd fail at create-payment-intent's
--    banking gate, but the user got a result they couldn't book — bad UX
--    and a leak of operational state).
--
-- 2. Enforce service.buffer_minutes between back-to-back appointments. Today,
--    appointments.ends_at is set by the client to starts_at + duration only
--    (no buffer). find_available_slots checks for overlap against ends_at, so
--    the next slot can begin the instant the previous one's service block
--    ends — leaving zero cleanup time even when buffer_minutes is set.
--    Fix: widen the conflict check to include buffer_minutes from the
--    existing appointment's service (joined in the conflict subquery).
-- =============================================================================

-- ── 1. curate_candidates: restore banking_complete gate ──────────────────
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
      AND st.position IN ('owner', 'stylist')
      AND b.is_active   = true
      AND b.is_verified  = true
      AND b.onboarding_complete = true
      AND b.banking_complete = true       -- RESTORED: 20260413 regression
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
  ORDER BY rs.distance_m, rs.slot_start
  LIMIT 50;
$$;

COMMENT ON FUNCTION public.curate_candidates IS
  'Discover bookable salons + slots. Gates: is_active, is_verified, '
  'onboarding_complete, banking_complete (restored build 60079). '
  'Diversity: ROW_NUMBER PARTITION BY staff_id, slot_rank <= 5.';

-- ── 2. find_available_slots: enforce buffer_minutes from existing appts ──
-- The conflict check now joins to services to add buffer_minutes onto each
-- existing appointment's effective end. New slot must clear by service buffer.
-- Buffer is per-existing-appointment (not the new one); the new appointment's
-- own buffer is enforced when ITS successor is booked.

CREATE OR REPLACE FUNCTION public.find_available_slots(
  p_staff_id uuid,
  p_duration_minutes integer,
  p_window_start timestamptz,
  p_window_end timestamptz
)
RETURNS TABLE (
  staff_id uuid,
  slot_start timestamptz,
  slot_end timestamptz,
  date date
)
LANGUAGE plpgsql
STABLE
AS $$
declare
  v_date date;
  v_dow smallint;
  v_schedule record;
  v_slot_start timestamptz;
  v_slot_end timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_override record;
  v_biz_hours jsonb;
  v_biz_id uuid;
  v_day_key text;
  v_biz_open time;
  v_biz_close time;
  v_day_names text[] := ARRAY['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
  v_has_services boolean;
begin
  SELECT EXISTS(SELECT 1 FROM staff_services ss WHERE ss.staff_id = p_staff_id) INTO v_has_services;
  IF NOT v_has_services THEN RETURN; END IF;

  IF NOT EXISTS(SELECT 1 FROM staff st WHERE st.id = p_staff_id AND st.position IN ('owner', 'stylist')) THEN
    RETURN;
  END IF;

  SELECT b.hours::jsonb, b.id INTO v_biz_hours, v_biz_id
  FROM staff st JOIN businesses b ON b.id = st.business_id
  WHERE st.id = p_staff_id;

  v_date := p_window_start::date;
  WHILE v_date <= p_window_end::date LOOP
    v_dow := extract(dow from v_date)::smallint;
    v_day_key := v_day_names[v_dow + 1];

    IF v_biz_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM business_closures bc
      WHERE bc.business_id = v_biz_id AND bc.closure_date = v_date AND bc.all_day = true
    ) THEN
      v_date := v_date + 1; CONTINUE;
    END IF;

    IF v_biz_hours IS NOT NULL THEN
      IF v_biz_hours->>v_day_key IS NULL OR (v_biz_hours->v_day_key) IS NULL THEN
        v_date := v_date + 1; CONTINUE;
      END IF;
      IF (v_biz_hours->v_day_key->>'open') IS NULL OR (v_biz_hours->v_day_key->>'close') IS NULL THEN
        v_date := v_date + 1; CONTINUE;
      END IF;
      v_biz_open := (v_biz_hours->v_day_key->>'open')::time;
      v_biz_close := (v_biz_hours->v_day_key->>'close')::time;
    END IF;

    SELECT * INTO v_override FROM staff_availability_overrides sao
    WHERE sao.staff_id = p_staff_id AND sao.override_date = v_date
      AND sao.is_available = false AND sao.start_time IS NULL LIMIT 1;
    IF FOUND THEN v_date := v_date + 1; CONTINUE; END IF;

    SELECT ssc.start_time, ssc.end_time INTO v_schedule
    FROM staff_schedules ssc WHERE ssc.staff_id = p_staff_id AND ssc.day_of_week = v_dow AND ssc.is_available = true;

    IF FOUND THEN
      v_day_start := v_date + v_schedule.start_time;
      v_day_end := v_date + v_schedule.end_time;

      IF v_biz_hours IS NOT NULL AND v_biz_open IS NOT NULL THEN
        IF v_date + v_biz_open > v_day_start THEN v_day_start := v_date + v_biz_open; END IF;
        IF v_date + v_biz_close < v_day_end THEN v_day_end := v_date + v_biz_close; END IF;
      END IF;

      IF v_day_start < p_window_start THEN v_day_start := p_window_start; END IF;
      IF v_day_end > p_window_end THEN v_day_end := p_window_end; END IF;

      v_slot_start := v_day_start;
      WHILE v_slot_start + (p_duration_minutes || ' minutes')::interval <= v_day_end LOOP
        v_slot_end := v_slot_start + (p_duration_minutes || ' minutes')::interval;

        -- Conflict check: existing appointment's effective end is its ends_at
        -- PLUS its service buffer_minutes. So a 60min service with 15min buffer
        -- ending 11:00 reserves the staff until 11:15; next slot can't start
        -- before 11:15. Buffer comes from services table, not the appointment.
        IF NOT EXISTS (
          SELECT 1 FROM appointments a
          LEFT JOIN services s ON s.id = a.service_id
          WHERE a.staff_id = p_staff_id
            AND a.status NOT IN ('cancelled_customer', 'cancelled_business', 'no_show')
            AND a.starts_at < v_slot_end
            AND (a.ends_at + (COALESCE(s.buffer_minutes, 0) || ' minutes')::interval) > v_slot_start
        )
        AND NOT EXISTS (
          SELECT 1 FROM external_appointments ea
          WHERE ea.staff_id = p_staff_id
            AND ea.starts_at < v_slot_end AND ea.ends_at > v_slot_start
        )
        THEN
          staff_id := p_staff_id;
          slot_start := v_slot_start;
          slot_end := v_slot_end;
          date := v_date;
          RETURN NEXT;
        END IF;

        v_slot_start := v_slot_start + interval '15 minutes';
      END LOOP;
    END IF;

    v_date := v_date + 1;
  END LOOP;
end;
$$;

COMMENT ON FUNCTION public.find_available_slots IS
  'Generate available booking slots for a staff member. Honors business hours, '
  'business_closures, staff_schedules, staff_availability_overrides, existing '
  'appointments + services.buffer_minutes (build 60079), external_appointments. '
  'Stride: 15 minutes.';
