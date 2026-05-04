-- =============================================================================
-- 20260504000002 — admin_get_user_full_profile: close anon NULL-bypass
-- =============================================================================
-- Same anti-pattern as the admin_get_user_auth_info fix in 20260504000001:
--   SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller;
--   IF v_caller_role NOT IN ('admin', 'superadmin') THEN RAISE 'Unauthorized'; END IF;
-- For anon, auth.uid() = NULL → no profiles row → caller_role = NULL → the
-- IF condition evaluates to NULL → IF NULL THEN does NOT raise → function
-- continues. Anon is only blocked downstream because admin_trait_access_log
-- has admin_id NOT NULL — without that incidental constraint, the full user
-- payload (profile, auth, business, saldo, appointments, ledger, traits…)
-- would be returned to anon.
--
-- Caught by manual probe 2026-05-04 while sweeping for sister cases of the
-- BC Monitor finding on admin_get_user_auth_info.
--
-- Fix: route through public.is_admin() (EXISTS-based, NULL-safe). Remove
-- v_caller_role declaration; nothing else uses it.
--
-- This closes the systemic anti-pattern audit. Probed 6 other admin RPCs
-- (list_users_with_traits, get_user_trait_data, pipeline_funnel_stats_filtered,
-- get_users_trait_summary, mark_role_change_request, approve_role_change) —
-- all already gated by `IF auth.uid() IS NULL` or `is_superadmin()`, so anon
-- is rejected at AUTH_REQUIRED. Only admin_get_user_full_profile lacked the
-- NULL guard.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_full_profile(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_now timestamptz := now();
  v_profile jsonb;
  v_auth jsonb;
  v_business jsonb;
  v_saldo jsonb;
  v_appointments jsonb;
  v_orders jsonb;
  v_loyalty jsonb;
  v_gift_cards jsonb;
  v_disputes jsonb;
  v_reviews jsonb;
  v_chat jsonb;
  v_media jsonb;
  v_invites jsonb;
  v_traits jsonb;
  v_summary jsonb;
  v_notes jsonb;
  v_target_exists boolean;
  v_webauthn_count int := 0;
  v_webauthn_exists boolean;
BEGIN
  -- Auth gate (NULL-safe via is_admin EXISTS — pre-fix used
  -- `caller_role NOT IN (...)` which evaluates to NULL for anon callers
  -- and silently bypassed the role check)
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  -- Target existence
  SELECT EXISTS(SELECT 1 FROM profiles WHERE id = p_user_id) INTO v_target_exists;
  IF NOT v_target_exists THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  -- Log trait access (reused table from admin_view_user_traits)
  INSERT INTO admin_trait_access_log (admin_id, viewed_user_id, context)
  VALUES (v_caller, p_user_id, 'full_profile_view');

  -- webauthn_credentials may not yet exist on this environment (migration
  -- 20260402000008 has not landed on prod). Probe dynamically so the
  -- function stays portable across envs.
  SELECT EXISTS(
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'webauthn_credentials'
  ) INTO v_webauthn_exists;
  IF v_webauthn_exists THEN
    EXECUTE format(
      'SELECT count(*)::int FROM public.webauthn_credentials WHERE user_id = %L',
      p_user_id
    ) INTO v_webauthn_count;
  END IF;

  -- ═════════════════════════════════════════════════════════════════════
  -- 1. Profile + auth
  -- ═════════════════════════════════════════════════════════════════════
  SELECT to_jsonb(p) - 'uber_access_token' - 'uber_refresh_token'
  INTO v_profile
  FROM profiles p WHERE p.id = p_user_id;

  SELECT jsonb_build_object(
    'email', u.email,
    'email_confirmed_at', u.email_confirmed_at,
    'phone', u.phone,
    'phone_confirmed_at', u.phone_confirmed_at,
    'last_sign_in_at', u.last_sign_in_at,
    'created_at', u.created_at,
    'providers', COALESCE((
      SELECT jsonb_agg(DISTINCT i.provider)
      FROM auth.identities i WHERE i.user_id = u.id
    ), '[]'::jsonb),
    'has_password', (u.encrypted_password IS NOT NULL AND u.encrypted_password <> ''),
    'webauthn_credential_count', v_webauthn_count,
    'active_qr_sessions', (
      SELECT count(*) FROM qr_auth_sessions
      WHERE user_id = p_user_id AND expires_at > v_now
    ),
    'banned_until', u.banned_until
  )
  INTO v_auth
  FROM auth.users u WHERE u.id = p_user_id;

  -- ═════════════════════════════════════════════════════════════════════
  -- 2. Business (if this user owns one)
  -- ═════════════════════════════════════════════════════════════════════
  SELECT COALESCE(
    jsonb_agg(jsonb_build_object(
      'id', b.id,
      'name', b.name,
      'is_active', b.is_active,
      'is_verified', b.is_verified,
      'tier', b.tier,
      'city', b.city,
      'stripe_charges_enabled', b.stripe_charges_enabled,
      'onboarding_step', b.onboarding_step,
      'average_rating', b.average_rating,
      'total_reviews', b.total_reviews,
      'pos_enabled', b.pos_enabled,
      'created_at', b.created_at
    )),
    '[]'::jsonb
  )
  INTO v_business
  FROM businesses b WHERE b.owner_id = p_user_id;

  -- ═════════════════════════════════════════════════════════════════════
  -- 3. Saldo + recent ledger
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'current_balance', (SELECT COALESCE(saldo, 0) FROM profiles WHERE id = p_user_id),
    'lifetime_credits', COALESCE((
      SELECT sum(amount) FROM saldo_ledger
      WHERE user_id = p_user_id AND amount > 0
    ), 0),
    'lifetime_debits', COALESCE((
      SELECT sum(amount) FROM saldo_ledger
      WHERE user_id = p_user_id AND amount < 0
    ), 0),
    'ledger_count', (SELECT count(*) FROM saldo_ledger WHERE user_id = p_user_id),
    'recent_ledger', COALESCE((
      SELECT jsonb_agg(row_to_json(l) ORDER BY l.created_at DESC)
      FROM (
        SELECT id, amount, reason, created_at
        FROM saldo_ledger
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 20
      ) l
    ), '[]'::jsonb)
  )
  INTO v_saldo;

  -- ═════════════════════════════════════════════════════════════════════
  -- 4. Appointments (counts by status, totals, recent)
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'total', (SELECT count(*) FROM appointments WHERE user_id = p_user_id),
    'by_status', COALESCE((
      SELECT jsonb_object_agg(status, cnt)
      FROM (
        SELECT status, count(*) AS cnt
        FROM appointments
        WHERE user_id = p_user_id
        GROUP BY status
      ) s
    ), '{}'::jsonb),
    'lifetime_spend', COALESCE((
      SELECT sum(COALESCE(price, 0))
      FROM appointments
      WHERE user_id = p_user_id AND status IN ('confirmed', 'completed')
    ), 0),
    'lifetime_refunded', COALESCE((
      SELECT sum(COALESCE(refund_amount, 0))
      FROM appointments
      WHERE user_id = p_user_id
    ), 0),
    'last_booking_at', (
      SELECT max(created_at) FROM appointments WHERE user_id = p_user_id
    ),
    'next_upcoming', (
      SELECT to_jsonb(a) FROM (
        SELECT id, service_name, starts_at, status, business_id
        FROM appointments
        WHERE user_id = p_user_id
          AND starts_at > v_now
          AND status IN ('pending', 'confirmed')
        ORDER BY starts_at ASC LIMIT 1
      ) a
    ),
    'recent', COALESCE((
      SELECT jsonb_agg(to_jsonb(a))
      FROM (
        SELECT
          a.id, a.service_name, a.status, a.payment_status, a.price,
          a.starts_at, a.created_at, a.business_id,
          b.name AS business_name
        FROM appointments a
        LEFT JOIN businesses b ON b.id = a.business_id
        WHERE a.user_id = p_user_id
        ORDER BY a.created_at DESC
        LIMIT 20
      ) a
    ), '[]'::jsonb)
  )
  INTO v_appointments;

  -- ═════════════════════════════════════════════════════════════════════
  -- 5. Orders (marketplace)
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'total', (SELECT count(*) FROM orders WHERE buyer_id = p_user_id),
    'by_status', COALESCE((
      SELECT jsonb_object_agg(status, cnt)
      FROM (
        SELECT status, count(*) AS cnt
        FROM orders
        WHERE buyer_id = p_user_id
        GROUP BY status
      ) s
    ), '{}'::jsonb),
    'lifetime_spend', COALESCE((
      SELECT sum(total_amount) FROM orders
      WHERE buyer_id = p_user_id AND status IN ('paid', 'shipped', 'delivered', 'completed')
    ), 0),
    'recent', COALESCE((
      SELECT jsonb_agg(to_jsonb(o))
      FROM (
        SELECT
          o.id, o.product_name, o.quantity, o.total_amount,
          o.status, o.created_at, o.business_id,
          b.name AS business_name
        FROM orders o
        LEFT JOIN businesses b ON b.id = o.business_id
        WHERE o.buyer_id = p_user_id
        ORDER BY o.created_at DESC
        LIMIT 10
      ) o
    ), '[]'::jsonb)
  )
  INTO v_orders;

  -- ═════════════════════════════════════════════════════════════════════
  -- 6. Loyalty
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'points_balance', COALESCE((
      SELECT sum(points) FROM loyalty_transactions WHERE user_id = p_user_id
    ), 0),
    'transactions', (SELECT count(*) FROM loyalty_transactions WHERE user_id = p_user_id)
  )
  INTO v_loyalty;

  -- ═════════════════════════════════════════════════════════════════════
  -- 7. Gift cards (user is only ever on the redemption side — issuer is
  -- the business, recorded via business_id + buyer_name text)
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'redeemed_count', (SELECT count(*) FROM gift_cards WHERE redeemed_by = p_user_id),
    'redeemed_total_value', COALESCE((
      SELECT sum(amount) FROM gift_cards WHERE redeemed_by = p_user_id
    ), 0),
    'recent_redeemed', COALESCE((
      SELECT jsonb_agg(to_jsonb(g))
      FROM (
        SELECT id, code, amount, redeemed_at, business_id
        FROM gift_cards
        WHERE redeemed_by = p_user_id
        ORDER BY redeemed_at DESC NULLS LAST
        LIMIT 5
      ) g
    ), '[]'::jsonb)
  )
  INTO v_gift_cards;

  -- ═════════════════════════════════════════════════════════════════════
  -- 8. Disputes
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'filed_total', (SELECT count(*) FROM disputes WHERE user_id = p_user_id),
    'by_status', COALESCE((
      SELECT jsonb_object_agg(status, cnt)
      FROM (
        SELECT status, count(*) AS cnt
        FROM disputes
        WHERE user_id = p_user_id
        GROUP BY status
      ) s
    ), '{}'::jsonb),
    'recent', COALESCE((
      SELECT jsonb_agg(to_jsonb(d))
      FROM (
        SELECT id, reason, status, refund_amount, created_at
        FROM disputes
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 10
      ) d
    ), '[]'::jsonb)
  )
  INTO v_disputes;

  -- ═════════════════════════════════════════════════════════════════════
  -- 9. Reviews given
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'given_total', (SELECT count(*) FROM reviews WHERE user_id = p_user_id),
    'avg_rating_given', COALESCE((
      SELECT round(avg(rating)::numeric, 2) FROM reviews WHERE user_id = p_user_id
    ), 0),
    'recent', COALESCE((
      SELECT jsonb_agg(to_jsonb(r))
      FROM (
        SELECT id, rating, comment, created_at, business_id
        FROM reviews
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 10
      ) r
    ), '[]'::jsonb)
  )
  INTO v_reviews;

  -- ═════════════════════════════════════════════════════════════════════
  -- 10. Chat threads
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'total', (SELECT count(*) FROM chat_threads WHERE user_id = p_user_id),
    'by_contact_type', COALESCE((
      SELECT jsonb_object_agg(contact_type, cnt)
      FROM (
        SELECT contact_type, count(*) AS cnt
        FROM chat_threads
        WHERE user_id = p_user_id
        GROUP BY contact_type
      ) s
    ), '{}'::jsonb),
    'unread_total', COALESCE((
      SELECT sum(COALESCE(unread_count, 0))
      FROM chat_threads WHERE user_id = p_user_id
    ), 0)
  )
  INTO v_chat;

  -- ═════════════════════════════════════════════════════════════════════
  -- 11. Media + invites + interest signals
  -- ═════════════════════════════════════════════════════════════════════
  SELECT jsonb_build_object(
    'uploaded_count', (SELECT count(*) FROM user_media WHERE user_id = p_user_id)
  )
  INTO v_media;

  SELECT jsonb_build_object(
    'invites_sent', (SELECT count(*) FROM user_salon_invites WHERE user_id = p_user_id),
    'invites_delivered', (
      SELECT count(*) FROM user_salon_invites
      WHERE user_id = p_user_id AND platform_message_sent = true
    ),
    'interest_signals', (
      SELECT count(*) FROM salon_interest_signals WHERE user_id = p_user_id
    )
  )
  INTO v_invites;

  -- ═════════════════════════════════════════════════════════════════════
  -- 12. Behavioral intelligence — compute fresh then fetch
  -- ═════════════════════════════════════════════════════════════════════
  PERFORM compute_user_traits(p_user_id);

  SELECT COALESCE(jsonb_object_agg(trait, jsonb_build_object(
    'score', score, 'raw_value', raw_value, 'computed_at', computed_at
  )), '{}'::jsonb)
  INTO v_traits
  FROM user_trait_scores WHERE user_id = p_user_id;

  SELECT to_jsonb(s) - 'user_id'
  INTO v_summary
  FROM user_behavior_summaries s WHERE user_id = p_user_id;

  -- ═════════════════════════════════════════════════════════════════════
  -- 13. Admin notes on this user
  -- ═════════════════════════════════════════════════════════════════════
  SELECT COALESCE(
    jsonb_agg(jsonb_build_object(
      'id', n.id,
      'note', n.note,
      'created_at', n.created_at,
      'created_by', n.created_by,
      'created_by_username', (SELECT username FROM profiles WHERE id = n.created_by)
    ) ORDER BY n.created_at DESC),
    '[]'::jsonb
  )
  INTO v_notes
  FROM admin_notes n
  WHERE n.target_type = 'user' AND n.target_id = p_user_id;

  -- ═════════════════════════════════════════════════════════════════════
  -- Final assembly
  -- ═════════════════════════════════════════════════════════════════════
  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'profile', COALESCE(v_profile, '{}'::jsonb),
    'auth', COALESCE(v_auth, '{}'::jsonb),
    'business', v_business,
    'saldo', v_saldo,
    'appointments', v_appointments,
    'orders', v_orders,
    'loyalty', v_loyalty,
    'gift_cards', v_gift_cards,
    'disputes', v_disputes,
    'reviews', v_reviews,
    'chat', v_chat,
    'media', v_media,
    'invites', v_invites,
    'intelligence', jsonb_build_object(
      'traits', v_traits,
      'summary', COALESCE(v_summary, '{}'::jsonb)
    ),
    'admin_notes', v_notes,
    'accessed_by', v_caller,
    'accessed_at', v_now
  );
END;
$$;


GRANT EXECUTE ON FUNCTION public.admin_get_user_full_profile(uuid) TO authenticated;

COMMENT ON FUNCTION public.admin_get_user_full_profile(uuid) IS
  'Aggregates every user-adjacent table into one jsonb for the admin user-detail view. '
  'Admin/superadmin only (NULL-safe via is_admin). Computes behavioral traits on-demand. '
  'Logs access to admin_trait_access_log under context=full_profile_view.';

