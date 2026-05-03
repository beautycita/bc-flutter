-- =============================================================================
-- 20260503000002 — businesses.timezone + slot generator local-time semantics
-- =============================================================================
-- `businesses.hours` stores plain wall-clock strings ("09:00"/"20:00") with
-- no timezone. find_available_slots cast them with `v_date + v_biz_open`,
-- which yields a TIMESTAMP that PostgreSQL converts to TIMESTAMPTZ using the
-- SESSION timezone (UTC in supabase Docker). Result: a Puerto Vallarta salon
-- with hours 09:00-20:00 emitted slots starting at 09:00 UTC = 03:00 MX
-- local. Customer-facing display read "open at 3 AM" — this would also bite
-- any check that compares slot_start to b.hours.
--
-- Fix:
--   1. Add timezone TEXT NOT NULL DEFAULT 'America/Mexico_City' on businesses.
--      Mexico-only platform today; MX has 4 timezones but PV/Jalisco/CDMX/
--      most of the country is America/Mexico_City. Backfill takes the
--      default and onboarding can refine per-salon later.
--   2. Rewrite find_available_slots to interpret hours + staff_schedule as
--      local-wall-clock in the salon's timezone. Cast each (date+time) via
--      AT TIME ZONE v_timezone so the resulting timestamptz is anchored
--      correctly across DST.
-- =============================================================================

-- ─── 1. Schema + backfill ─────────────────────────────────────────────────
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'America/Mexico_City';

COMMENT ON COLUMN public.businesses.timezone IS
  'IANA timezone name (e.g. America/Mexico_City). Used by find_available_slots to anchor `hours` JSON wall-clock times to the correct UTC instant.';

-- ─── 2. Slot generator with TZ awareness ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.find_available_slots(
  p_staff_id          uuid,
  p_duration_minutes  integer,
  p_window_start      timestamp with time zone,
  p_window_end        timestamp with time zone
)
RETURNS TABLE (
  staff_id   uuid,
  slot_start timestamp with time zone,
  slot_end   timestamp with time zone,
  date       date
)
LANGUAGE plpgsql STABLE
AS $function$
DECLARE
  v_date          date;
  v_dow           smallint;
  v_schedule      record;
  v_slot_start    timestamptz;
  v_slot_end      timestamptz;
  v_day_start     timestamptz;
  v_day_end       timestamptz;
  v_override      record;
  v_biz_hours     jsonb;
  v_biz_id        uuid;
  v_biz_tz        text;
  v_day_key       text;
  v_biz_open      time;
  v_biz_close     time;
  v_biz_open_ts   timestamptz;
  v_biz_close_ts  timestamptz;
  v_day_names     text[] := ARRAY['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
  v_has_services  boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM staff_services ss WHERE ss.staff_id = p_staff_id)
    INTO v_has_services;
  IF NOT v_has_services THEN RETURN; END IF;

  IF NOT EXISTS(
    SELECT 1 FROM staff st
     WHERE st.id = p_staff_id AND st.position IN ('owner','stylist')
  ) THEN RETURN; END IF;

  SELECT b.hours::jsonb, b.id, COALESCE(b.timezone, 'America/Mexico_City')
    INTO v_biz_hours, v_biz_id, v_biz_tz
    FROM staff st JOIN businesses b ON b.id = st.business_id
   WHERE st.id = p_staff_id;

  -- Iterate each calendar day in the salon's local timezone, not UTC. A
  -- midnight-spanning UTC window can otherwise skip or double-count a day.
  v_date := (p_window_start AT TIME ZONE v_biz_tz)::date;
  WHILE v_date <= (p_window_end AT TIME ZONE v_biz_tz)::date LOOP
    v_dow := extract(dow from v_date)::smallint;
    v_day_key := v_day_names[v_dow + 1];

    IF v_biz_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM business_closures bc
       WHERE bc.business_id = v_biz_id
         AND bc.closure_date = v_date
         AND bc.all_day = true
    ) THEN
      v_date := v_date + 1; CONTINUE;
    END IF;

    IF v_biz_hours IS NOT NULL THEN
      IF v_biz_hours->>v_day_key IS NULL OR (v_biz_hours->v_day_key) IS NULL THEN
        v_date := v_date + 1; CONTINUE;
      END IF;
      IF (v_biz_hours->v_day_key->>'open') IS NULL
         OR (v_biz_hours->v_day_key->>'close') IS NULL THEN
        v_date := v_date + 1; CONTINUE;
      END IF;
      v_biz_open  := (v_biz_hours->v_day_key->>'open')::time;
      v_biz_close := (v_biz_hours->v_day_key->>'close')::time;
      -- Anchor wall-clock times to the salon's timezone, NOT the session
      -- timezone (which is UTC in supabase Docker).
      v_biz_open_ts  := (v_date::text || ' ' || v_biz_open::text)::timestamp
                          AT TIME ZONE v_biz_tz;
      v_biz_close_ts := (v_date::text || ' ' || v_biz_close::text)::timestamp
                          AT TIME ZONE v_biz_tz;
    END IF;

    SELECT * INTO v_override
      FROM staff_availability_overrides sao
     WHERE sao.staff_id = p_staff_id
       AND sao.override_date = v_date
       AND sao.is_available = false
       AND sao.start_time IS NULL
     LIMIT 1;
    IF FOUND THEN v_date := v_date + 1; CONTINUE; END IF;

    SELECT ssc.start_time, ssc.end_time INTO v_schedule
      FROM staff_schedules ssc
     WHERE ssc.staff_id = p_staff_id
       AND ssc.day_of_week = v_dow
       AND ssc.is_available = true;

    IF FOUND THEN
      -- Same TZ anchoring for staff_schedules wall-clock times.
      v_day_start := (v_date::text || ' ' || v_schedule.start_time::text)::timestamp
                       AT TIME ZONE v_biz_tz;
      v_day_end   := (v_date::text || ' ' || v_schedule.end_time::text)::timestamp
                       AT TIME ZONE v_biz_tz;

      IF v_biz_hours IS NOT NULL AND v_biz_open_ts IS NOT NULL THEN
        IF v_biz_open_ts  > v_day_start THEN v_day_start := v_biz_open_ts;  END IF;
        IF v_biz_close_ts < v_day_end   THEN v_day_end   := v_biz_close_ts; END IF;
      END IF;

      IF v_day_start < p_window_start THEN v_day_start := p_window_start; END IF;
      IF v_day_end   > p_window_end   THEN v_day_end   := p_window_end;   END IF;

      v_slot_start := v_day_start;
      WHILE v_slot_start + (p_duration_minutes || ' minutes')::interval <= v_day_end LOOP
        v_slot_end := v_slot_start + (p_duration_minutes || ' minutes')::interval;

        IF NOT EXISTS (
          SELECT 1 FROM appointments a
          LEFT JOIN services s ON s.id = a.service_id
          WHERE a.staff_id = p_staff_id
            AND a.status NOT IN ('cancelled_customer','cancelled_business','no_show')
            AND a.starts_at < v_slot_end
            AND (a.ends_at + (COALESCE(s.buffer_minutes, 0) || ' minutes')::interval) > v_slot_start
        )
        AND NOT EXISTS (
          SELECT 1 FROM external_appointments ea
           WHERE ea.staff_id = p_staff_id
             AND ea.starts_at < v_slot_end
             AND ea.ends_at   > v_slot_start
        )
        THEN
          staff_id   := p_staff_id;
          slot_start := v_slot_start;
          slot_end   := v_slot_end;
          date       := v_date;
          RETURN NEXT;
        END IF;

        v_slot_start := v_slot_start + interval '15 minutes';
      END LOOP;
    END IF;

    v_date := v_date + 1;
  END LOOP;
END;
$function$;

COMMENT ON FUNCTION public.find_available_slots(
  uuid, integer, timestamp with time zone, timestamp with time zone
) IS
  'Emits bookable slots for a staff member. Hours / staff_schedule wall-clock times are anchored to businesses.timezone so a 09:00 schedule means 09:00 LOCAL, not 09:00 UTC.';
