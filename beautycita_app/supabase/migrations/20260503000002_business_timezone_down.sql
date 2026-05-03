-- Reverse 20260503000002. Restores the UTC-interpretation slot generator and
-- drops the timezone column. NOTE: dropping the column will erase any
-- timezone overrides salons have set; only run this if you intend to fully
-- revert and re-introduce the bug.

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
  v_date         date;
  v_dow          smallint;
  v_schedule     record;
  v_slot_start   timestamptz;
  v_slot_end     timestamptz;
  v_day_start    timestamptz;
  v_day_end      timestamptz;
  v_override     record;
  v_biz_hours    jsonb;
  v_biz_id       uuid;
  v_day_key      text;
  v_biz_open     time;
  v_biz_close    time;
  v_day_names    text[] := ARRAY['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
  v_has_services boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM staff_services ss WHERE ss.staff_id = p_staff_id) INTO v_has_services;
  IF NOT v_has_services THEN RETURN; END IF;

  IF NOT EXISTS(SELECT 1 FROM staff st WHERE st.id = p_staff_id AND st.position IN ('owner','stylist')) THEN
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
    ) THEN v_date := v_date + 1; CONTINUE; END IF;

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
      FROM staff_schedules ssc
     WHERE ssc.staff_id = p_staff_id AND ssc.day_of_week = v_dow AND ssc.is_available = true;

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
           WHERE ea.staff_id = p_staff_id AND ea.starts_at < v_slot_end AND ea.ends_at > v_slot_start
        ) THEN
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
END;
$function$;

ALTER TABLE public.businesses DROP COLUMN IF EXISTS timezone;
