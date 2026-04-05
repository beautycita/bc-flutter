-- =============================================================================
-- Per-staff closures: allow individual staff members to have days off
-- while the rest of the salon stays open.
--
-- staff_id = NULL → whole salon closed (existing behavior)
-- staff_id = <uuid> → only that staff member is off
-- =============================================================================

-- 1. Add nullable staff_id FK
ALTER TABLE business_closures
  ADD COLUMN IF NOT EXISTS staff_id uuid REFERENCES staff(id) ON DELETE CASCADE;

-- 2. Drop old unique constraint (business_id, closure_date) and replace with
--    one that includes staff_id. Use COALESCE so NULL staff_id is treated as
--    a distinct value ('00000000-...') for uniqueness purposes.
ALTER TABLE business_closures
  DROP CONSTRAINT IF EXISTS business_closures_unique;

CREATE UNIQUE INDEX IF NOT EXISTS business_closures_unique_v2
  ON business_closures (business_id, closure_date, COALESCE(staff_id, '00000000-0000-0000-0000-000000000000'));

-- 3. Index for staff-level closure lookups
CREATE INDEX IF NOT EXISTS idx_business_closures_staff
  ON business_closures(staff_id, closure_date)
  WHERE staff_id IS NOT NULL;

-- 4. Update find_available_slots to respect per-staff closures
CREATE OR REPLACE FUNCTION find_available_slots(
  p_staff_id uuid,
  p_duration_minutes integer,
  p_window_start timestamptz,
  p_window_end timestamptz
)
RETURNS TABLE(
  staff_id uuid,
  slot_start timestamptz,
  slot_end timestamptz,
  date date
) LANGUAGE plpgsql STABLE AS $$
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
  -- Staff must have at least one service assigned
  SELECT EXISTS(SELECT 1 FROM staff_services WHERE staff_services.staff_id = p_staff_id) INTO v_has_services;
  IF NOT v_has_services THEN RETURN; END IF;

  -- Staff must be a bookable position
  IF NOT EXISTS(SELECT 1 FROM staff s WHERE s.id = p_staff_id AND s.position IN ('owner', 'stylist')) THEN
    RETURN;
  END IF;

  SELECT b.hours::jsonb, b.id INTO v_biz_hours, v_biz_id
  FROM staff st JOIN businesses b ON b.id = st.business_id
  WHERE st.id = p_staff_id;

  v_date := p_window_start::date;
  WHILE v_date <= p_window_end::date LOOP
    v_dow := extract(dow from v_date)::smallint;
    v_day_key := v_day_names[v_dow + 1];

    -- Check business-wide closures (all-day, staff_id IS NULL)
    IF v_biz_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM business_closures
      WHERE business_id = v_biz_id AND closure_date = v_date AND all_day = true AND staff_id IS NULL
    ) THEN
      v_date := v_date + 1;
      CONTINUE;
    END IF;

    -- Check per-staff all-day closure
    IF EXISTS(
      SELECT 1 FROM business_closures
      WHERE business_id = v_biz_id AND closure_date = v_date AND all_day = true
        AND business_closures.staff_id = p_staff_id
    ) THEN
      v_date := v_date + 1;
      CONTINUE;
    END IF;

    -- Check business hours
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

    -- Check staff override (day off)
    SELECT * INTO v_override FROM staff_availability_overrides sao
    WHERE sao.staff_id = p_staff_id AND sao.override_date = v_date
      AND sao.is_available = false AND sao.start_time IS NULL
    LIMIT 1;
    IF FOUND THEN v_date := v_date + 1; CONTINUE; END IF;

    -- Get staff schedule for this day
    SELECT ss.start_time, ss.end_time INTO v_schedule
    FROM staff_schedules ss
    WHERE ss.staff_id = p_staff_id AND ss.day_of_week = v_dow AND ss.is_available = true;

    IF FOUND THEN
      v_day_start := v_date + v_schedule.start_time;
      v_day_end := v_date + v_schedule.end_time;

      -- Clamp to business hours
      IF v_biz_hours IS NOT NULL AND v_biz_open IS NOT NULL THEN
        IF v_date + v_biz_open > v_day_start THEN v_day_start := v_date + v_biz_open; END IF;
        IF v_date + v_biz_close < v_day_end THEN v_day_end := v_date + v_biz_close; END IF;
      END IF;

      -- Clamp to search window
      IF v_day_start < p_window_start THEN v_day_start := p_window_start; END IF;
      IF v_day_end > p_window_end THEN v_day_end := p_window_end; END IF;

      -- Generate slots
      v_slot_start := v_day_start;
      WHILE v_slot_start + (p_duration_minutes || ' minutes')::interval <= v_day_end LOOP
        v_slot_end := v_slot_start + (p_duration_minutes || ' minutes')::interval;

        -- Check no conflicting appointments
        IF NOT EXISTS (
          SELECT 1 FROM appointments a
          WHERE a.staff_id = p_staff_id
            AND a.status NOT IN ('cancelled_customer', 'cancelled_business', 'no_show')
            AND a.starts_at < v_slot_end
            AND a.ends_at > v_slot_start
        )
        -- Check no conflicting external appointments
        AND NOT EXISTS (
          SELECT 1 FROM external_appointments ea
          WHERE ea.staff_id = p_staff_id
            AND ea.starts_at < v_slot_end
            AND ea.ends_at > v_slot_start
        )
        -- Check no business-wide partial-day closure blocking this slot
        AND NOT EXISTS (
          SELECT 1 FROM business_closures bc
          WHERE bc.business_id = v_biz_id
            AND bc.closure_date = v_date
            AND bc.all_day = false
            AND bc.staff_id IS NULL
            AND bc.start_time IS NOT NULL
            AND bc.end_time IS NOT NULL
            AND (v_date + bc.start_time) < v_slot_end
            AND (v_date + bc.end_time) > v_slot_start
        )
        -- Check no per-staff partial-day closure blocking this slot
        AND NOT EXISTS (
          SELECT 1 FROM business_closures bc
          WHERE bc.business_id = v_biz_id
            AND bc.closure_date = v_date
            AND bc.all_day = false
            AND bc.staff_id = p_staff_id
            AND bc.start_time IS NOT NULL
            AND bc.end_time IS NOT NULL
            AND (v_date + bc.start_time) < v_slot_end
            AND (v_date + bc.end_time) > v_slot_start
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
