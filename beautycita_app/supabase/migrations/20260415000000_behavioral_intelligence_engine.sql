-- Behavioral Intelligence Engine: trait computation + trigger evaluation
-- 8 traits (reduced from 50 per BC decision), configurable triggers

-- ============================================================
-- 1. Fix trigger seeds to use the 8-trait names
-- ============================================================
DELETE FROM behavior_triggers;

INSERT INTO behavior_triggers (name, description, conditions, action, action_params) VALUES
  ('RP Scout',
   'High initiative + referral impact + geographic spread = potential RP candidate',
   '[{"trait": "initiative", "op": ">=", "value": 60}, {"trait": "referral_impact", "op": ">=", "value": 50}, {"trait": "geographic_spread", "op": ">=", "value": 40}]'::jsonb,
   'alert',
   '{"label": "RP Candidate", "severity": "info"}'::jsonb),

  ('Whale Alert',
   'High spend velocity + consistent usage = high-value user',
   '[{"trait": "spend_velocity", "op": ">=", "value": 80}, {"trait": "consistency", "op": ">=", "value": 70}]'::jsonb,
   'alert',
   '{"label": "High-Value User", "severity": "info"}'::jsonb),

  ('Churn Warning',
   'High churn risk + has meaningful spend history',
   '[{"trait": "churn_risk", "op": ">=", "value": 75}, {"trait": "spend_velocity", "op": ">=", "value": 30}]'::jsonb,
   'alert',
   '{"label": "Churn Risk", "severity": "warning"}'::jsonb),

  ('Fraud Signal',
   'Very high cancellation rate + low payment reliability',
   '[{"trait": "cancellation_rate", "op": ">=", "value": 85}, {"trait": "payment_reliability", "op": "<=", "value": 25}]'::jsonb,
   'alert',
   '{"label": "Possible Fraud", "severity": "critical"}'::jsonb);

-- ============================================================
-- 2. Trait computation RPC
-- ============================================================
CREATE OR REPLACE FUNCTION compute_user_traits(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_now timestamptz := now();
  v_events_90d int;
  v_first_event timestamptz;
  v_last_event timestamptz;
  v_active_months numeric;
BEGIN
  -- Basic event stats
  SELECT count(*), min(created_at), max(created_at)
  INTO v_events_90d, v_first_event, v_last_event
  FROM user_behavior_events
  WHERE user_id = p_user_id
    AND created_at > v_now - interval '90 days';

  -- Active months (minimum 1 to avoid division by zero)
  v_active_months := GREATEST(1, EXTRACT(EPOCH FROM (COALESCE(v_last_event, v_now) - COALESCE(v_first_event, v_now))) / (30 * 86400));

  -- ── TRAIT 1: initiative ──
  -- Actions taken without prompts: invites, reviews, content uploads
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'initiative',
    (SELECT count(*) FROM user_behavior_events
     WHERE user_id = p_user_id
       AND event_type IN ('invite_sent', 'review_submitted', 'content_created', 'salon_viewed')
       AND created_at > v_now - interval '90 days'),
    LEAST(100, (SELECT count(*) FROM user_behavior_events
     WHERE user_id = p_user_id
       AND event_type IN ('invite_sent', 'review_submitted', 'content_created', 'salon_viewed')
       AND created_at > v_now - interval '90 days') * 5.0),  -- 20 actions = 100
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 2: spend_velocity ──
  -- Total spend per active month (from appointments + orders)
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'spend_velocity',
    COALESCE((
      SELECT sum(price) FROM appointments
      WHERE user_id = p_user_id AND status IN ('confirmed', 'completed')
        AND created_at > v_now - interval '90 days'
    ), 0) + COALESCE((
      SELECT sum(total_amount) FROM orders
      WHERE buyer_id = p_user_id AND status IN ('confirmed', 'shipped', 'completed')
        AND created_at > v_now - interval '90 days'
    ), 0),
    LEAST(100, (
      (COALESCE((SELECT sum(price) FROM appointments WHERE user_id = p_user_id AND status IN ('confirmed', 'completed') AND created_at > v_now - interval '90 days'), 0)
       + COALESCE((SELECT sum(total_amount) FROM orders WHERE buyer_id = p_user_id AND status IN ('confirmed', 'shipped', 'completed') AND created_at > v_now - interval '90 days'), 0))
      / v_active_months / 50.0  -- $5000/month = 100
    )),
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 3: consistency ──
  -- Session regularity: low variance between app_opened events = reliable user
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'consistency',
    COALESCE((
      SELECT stddev(gap_hours) FROM (
        SELECT EXTRACT(EPOCH FROM (created_at - lag(created_at) OVER (ORDER BY created_at))) / 3600 AS gap_hours
        FROM user_behavior_events
        WHERE user_id = p_user_id
          AND event_type = 'app_opened'
          AND created_at > v_now - interval '90 days'
      ) sub WHERE gap_hours IS NOT NULL
    ), 999),
    -- Invert: lower stddev = higher score. <12h stddev = 100, >168h (1 week) = 0
    GREATEST(0, LEAST(100,
      100 - (COALESCE((
        SELECT stddev(gap_hours) FROM (
          SELECT EXTRACT(EPOCH FROM (created_at - lag(created_at) OVER (ORDER BY created_at))) / 3600 AS gap_hours
          FROM user_behavior_events
          WHERE user_id = p_user_id
            AND event_type = 'app_opened'
            AND created_at > v_now - interval '90 days'
        ) sub WHERE gap_hours IS NOT NULL
      ), 168) - 12) / 1.56
    )),
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 4: churn_risk ──
  -- Days since last action / avg days between actions
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'churn_risk',
    COALESCE(EXTRACT(EPOCH FROM (v_now - v_last_event)) / 86400, 90),
    -- 0 days since last = 0 risk, 30+ days = 100 risk
    LEAST(100, GREATEST(0,
      COALESCE(EXTRACT(EPOCH FROM (v_now - v_last_event)) / 86400, 90) / 0.3
    )),
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 5: referral_impact ──
  -- Invites that converted / total invites sent
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'referral_impact',
    COALESCE((
      SELECT count(*) FILTER (WHERE platform_message_sent = true)
      FROM user_salon_invites WHERE user_id = p_user_id
    ), 0),
    CASE
      WHEN (SELECT count(*) FROM user_salon_invites WHERE user_id = p_user_id) = 0 THEN 0
      ELSE LEAST(100, (
        SELECT count(*) FILTER (WHERE platform_message_sent = true)::numeric
          / GREATEST(1, count(*))::numeric * 100
        FROM user_salon_invites WHERE user_id = p_user_id
      ))
    END,
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 6: cancellation_rate ──
  -- Cancelled + no-show / total bookings (from appointments, not events)
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'cancellation_rate',
    COALESCE((
      SELECT count(*) FILTER (WHERE status IN ('cancelled', 'no_show'))
      FROM appointments WHERE user_id = p_user_id
    ), 0),
    CASE
      WHEN (SELECT count(*) FROM appointments WHERE user_id = p_user_id) = 0 THEN 0
      ELSE LEAST(100, (
        SELECT count(*) FILTER (WHERE status IN ('cancelled', 'no_show'))::numeric
          / GREATEST(1, count(*))::numeric * 100
        FROM appointments WHERE user_id = p_user_id
      ))
    END,
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 7: geographic_spread ──
  -- Unique cities with activity
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'geographic_spread',
    COALESCE((
      SELECT count(DISTINCT metadata->>'city')
      FROM user_behavior_events
      WHERE user_id = p_user_id
        AND metadata->>'city' IS NOT NULL
        AND created_at > v_now - interval '90 days'
    ), 0),
    -- 1 city = 10, 5 cities = 50, 10+ = 100
    LEAST(100, COALESCE((
      SELECT count(DISTINCT metadata->>'city') * 10
      FROM user_behavior_events
      WHERE user_id = p_user_id
        AND metadata->>'city' IS NOT NULL
        AND created_at > v_now - interval '90 days'
    ), 0)),
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── TRAIT 8: payment_reliability ──
  -- Successful payments / total payment attempts
  INSERT INTO user_trait_scores (user_id, trait, raw_value, score, computed_at)
  VALUES (
    p_user_id, 'payment_reliability',
    COALESCE((
      SELECT count(*) FILTER (WHERE payment_status = 'paid')
      FROM appointments WHERE user_id = p_user_id
    ), 0),
    CASE
      WHEN (SELECT count(*) FROM appointments WHERE user_id = p_user_id AND payment_status IS NOT NULL) = 0 THEN 50 -- neutral default
      ELSE LEAST(100, (
        SELECT count(*) FILTER (WHERE payment_status = 'paid')::numeric
          / GREATEST(1, count(*) FILTER (WHERE payment_status IS NOT NULL))::numeric * 100
        FROM appointments WHERE user_id = p_user_id
      ))
    END,
    v_now
  )
  ON CONFLICT (user_id, trait)
  DO UPDATE SET raw_value = EXCLUDED.raw_value, score = EXCLUDED.score, computed_at = v_now;

  -- ── Update user_behavior_summaries ──
  INSERT INTO user_behavior_summaries (
    user_id, total_events, first_event_at, last_event_at,
    active_days_30d, active_days_90d, primary_city, primary_state,
    top_event_types, segment,
    rp_candidate_score, whale_score, churn_risk_score, computed_at
  )
  VALUES (
    p_user_id,
    v_events_90d,
    v_first_event,
    v_last_event,
    (SELECT count(DISTINCT created_at::date) FROM user_behavior_events
     WHERE user_id = p_user_id AND created_at > v_now - interval '30 days'),
    (SELECT count(DISTINCT created_at::date) FROM user_behavior_events
     WHERE user_id = p_user_id AND created_at > v_now - interval '90 days'),
    (SELECT metadata->>'city' FROM user_behavior_events
     WHERE user_id = p_user_id AND metadata->>'city' IS NOT NULL
     GROUP BY metadata->>'city' ORDER BY count(*) DESC LIMIT 1),
    (SELECT metadata->>'state' FROM user_behavior_events
     WHERE user_id = p_user_id AND metadata->>'state' IS NOT NULL
     GROUP BY metadata->>'state' ORDER BY count(*) DESC LIMIT 1),
    COALESCE((
      SELECT jsonb_agg(jsonb_build_object('type', event_type, 'count', cnt) ORDER BY cnt DESC)
      FROM (
        SELECT event_type, count(*) as cnt
        FROM user_behavior_events
        WHERE user_id = p_user_id AND created_at > v_now - interval '90 days'
        GROUP BY event_type ORDER BY cnt DESC LIMIT 5
      ) sub
    ), '[]'::jsonb),
    CASE
      WHEN v_events_90d = 0 THEN 'new'
      WHEN v_last_event < v_now - interval '30 days' THEN 'dormant'
      WHEN v_events_90d < 10 THEN 'casual'
      WHEN v_events_90d < 50 THEN 'regular'
      ELSE 'power_user'
    END,
    -- Composite scores from traits
    COALESCE((SELECT score FROM user_trait_scores WHERE user_id = p_user_id AND trait = 'initiative'), 0),
    COALESCE((SELECT score FROM user_trait_scores WHERE user_id = p_user_id AND trait = 'spend_velocity'), 0),
    COALESCE((SELECT score FROM user_trait_scores WHERE user_id = p_user_id AND trait = 'churn_risk'), 0),
    v_now
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    total_events = EXCLUDED.total_events,
    first_event_at = EXCLUDED.first_event_at,
    last_event_at = EXCLUDED.last_event_at,
    active_days_30d = EXCLUDED.active_days_30d,
    active_days_90d = EXCLUDED.active_days_90d,
    primary_city = EXCLUDED.primary_city,
    primary_state = EXCLUDED.primary_state,
    top_event_types = EXCLUDED.top_event_types,
    segment = EXCLUDED.segment,
    rp_candidate_score = EXCLUDED.rp_candidate_score,
    whale_score = EXCLUDED.whale_score,
    churn_risk_score = EXCLUDED.churn_risk_score,
    computed_at = v_now;
END;
$$;

-- ============================================================
-- 3. Batch computation for all active users
-- ============================================================
CREATE OR REPLACE FUNCTION compute_all_user_traits()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int := 0;
  v_uid uuid;
BEGIN
  -- Compute for users with any activity in the last 90 days
  -- OR users with appointments
  FOR v_uid IN
    SELECT DISTINCT user_id FROM (
      SELECT user_id FROM user_behavior_events
      WHERE created_at > now() - interval '90 days'
      UNION
      SELECT user_id FROM appointments
      WHERE created_at > now() - interval '90 days'
      UNION
      SELECT id AS user_id FROM profiles
      WHERE last_seen > now() - interval '90 days'
    ) sub
  LOOP
    PERFORM compute_user_traits(v_uid);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- ============================================================
-- 4. Trigger evaluation engine
-- ============================================================
CREATE OR REPLACE FUNCTION evaluate_behavior_triggers()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trigger record;
  v_user record;
  v_conditions jsonb;
  v_condition jsonb;
  v_all_match boolean;
  v_score numeric;
  v_fires int := 0;
BEGIN
  FOR v_trigger IN
    SELECT * FROM behavior_triggers WHERE is_active = true
  LOOP
    v_conditions := v_trigger.conditions;

    -- Check each user that has trait scores
    FOR v_user IN
      SELECT DISTINCT user_id FROM user_trait_scores
    LOOP
      v_all_match := true;

      -- Check all conditions
      FOR v_condition IN SELECT * FROM jsonb_array_elements(v_conditions)
      LOOP
        SELECT score INTO v_score
        FROM user_trait_scores
        WHERE user_id = v_user.user_id
          AND trait = v_condition->>'trait';

        IF v_score IS NULL THEN
          v_all_match := false;
          EXIT;
        END IF;

        CASE v_condition->>'op'
          WHEN '>=' THEN
            IF v_score < (v_condition->>'value')::numeric THEN v_all_match := false; EXIT; END IF;
          WHEN '<=' THEN
            IF v_score > (v_condition->>'value')::numeric THEN v_all_match := false; EXIT; END IF;
          WHEN '>' THEN
            IF v_score <= (v_condition->>'value')::numeric THEN v_all_match := false; EXIT; END IF;
          WHEN '<' THEN
            IF v_score >= (v_condition->>'value')::numeric THEN v_all_match := false; EXIT; END IF;
          WHEN '=' THEN
            IF v_score != (v_condition->>'value')::numeric THEN v_all_match := false; EXIT; END IF;
          ELSE
            v_all_match := false; EXIT;
        END CASE;
      END LOOP;

      IF v_all_match THEN
        -- Only fire if not already fired for this user in the last 24 hours
        IF NOT EXISTS (
          SELECT 1 FROM behavior_trigger_log
          WHERE trigger_id = v_trigger.id
            AND user_id = v_user.user_id
            AND created_at > now() - interval '24 hours'
        ) THEN
          INSERT INTO behavior_trigger_log (trigger_id, user_id, matched_scores, created_at)
          VALUES (
            v_trigger.id,
            v_user.user_id,
            (SELECT jsonb_object_agg(trait, score)
             FROM user_trait_scores
             WHERE user_id = v_user.user_id),
            now()
          );

          -- Update trigger stats
          UPDATE behavior_triggers
          SET last_created_at = now(), fire_count = fire_count + 1
          WHERE id = v_trigger.id;

          v_fires := v_fires + 1;
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  RETURN v_fires;
END;
$$;

-- ============================================================
-- 5. Grant execute to service_role and authenticated
-- ============================================================
GRANT EXECUTE ON FUNCTION compute_user_traits(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION compute_all_user_traits() TO service_role;
GRANT EXECUTE ON FUNCTION evaluate_behavior_triggers() TO service_role;

-- Also allow admin panel to call via RPC
GRANT EXECUTE ON FUNCTION compute_user_traits(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION compute_all_user_traits() TO authenticated;
GRANT EXECUTE ON FUNCTION evaluate_behavior_triggers() TO authenticated;
