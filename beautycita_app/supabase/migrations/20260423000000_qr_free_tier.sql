-- =============================================================================
-- QR Free-Tier Program — Phase 1 Schema
-- =============================================================================
-- Implements the salon QR free-tier + ExpressCita external QR design.
-- Design doc: /home/bc/futureBeauty/docs/plans/2026-04-23-salon-qr-90day.md
-- Rev 2 approved 2026-04-23 with Jetsam findings 219-226 folded in.
-- =============================================================================

-- ─── Pre-flight: profiles.phone uniqueness gate (finding #220) ──────────────
-- Aborts hard if any duplicate phones exist. Human resolves + reruns.
DO $$
DECLARE
  dup_count int;
BEGIN
  SELECT count(*) INTO dup_count FROM (
    SELECT phone FROM public.profiles
    WHERE phone IS NOT NULL
    GROUP BY phone HAVING count(*) > 1
  ) d;
  IF dup_count > 0 THEN
    RAISE EXCEPTION
      'profiles.phone duplicates found (% phones with >1 row). Resolve before applying QR migration.', dup_count;
  END IF;
END $$;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_phone_unique UNIQUE (phone);
-- Postgres UNIQUE allows multiple NULLs, so profiles without phones remain fine.

-- ─── admin_alerts (finding #222) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_alerts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category     text NOT NULL,
  severity     text NOT NULL CHECK (severity IN ('info','warning','critical')),
  payload      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at  timestamptz,
  resolved_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolution   text
);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_unresolved
  ON public.admin_alerts(created_at DESC) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_admin_alerts_category
  ON public.admin_alerts(category);
ALTER TABLE public.admin_alerts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admin_alerts_admin_only ON public.admin_alerts;
CREATE POLICY admin_alerts_admin_only ON public.admin_alerts
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('admin','superadmin'))
  );
COMMENT ON TABLE public.admin_alerts IS
  'Unified admin-notification queue. Category examples: shared_device, walkin_expired.';

-- ─── wa_notification_queue (for salon-ghost notifications via cron) ────────
CREATE TABLE IF NOT EXISTS public.wa_notification_queue (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone         text NOT NULL,
  template      text NOT NULL,
  variables     jsonb NOT NULL DEFAULT '{}'::jsonb,
  status        text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed', 'dead')),
  attempts      int NOT NULL DEFAULT 0,
  last_error    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  sent_at       timestamptz,
  next_attempt_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_wa_queue_pending
  ON public.wa_notification_queue(next_attempt_at)
  WHERE status = 'pending';
ALTER TABLE public.wa_notification_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wa_queue_admin_only ON public.wa_notification_queue;
CREATE POLICY wa_queue_admin_only ON public.wa_notification_queue
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('admin','superadmin'))
  );
COMMENT ON TABLE public.wa_notification_queue IS
  'Outbound WA messages queued from plpgsql (where edge fn cannot be invoked). Drained by a worker edge function.';

-- ─── businesses extensions ──────────────────────────────────────────────────
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS free_tier_agreements_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS free_tier_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS external_qr_poster_claimed_at timestamptz,
  ADD COLUMN IF NOT EXISTS internal_qr_slug text;

-- internal_qr_slug must be unique across businesses (separate from portfolio slug)
CREATE UNIQUE INDEX IF NOT EXISTS idx_businesses_internal_qr_slug
  ON public.businesses(internal_qr_slug)
  WHERE internal_qr_slug IS NOT NULL;

COMMENT ON COLUMN public.businesses.free_tier_started_at IS
  'Set on first appointment INSERT by trigger. Start of the 90-day enrollment window.';
COMMENT ON COLUMN public.businesses.internal_qr_slug IS
  'Short opaque code for /registro/:slug. Separate from businesses.slug (portfolio URL).';

-- ─── salon_walkin_registrations ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.salon_walkin_registrations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  phone           text NOT NULL,
  full_name       text NOT NULL,
  device_uuid     text,
  ip_hash         text,
  user_agent_hash text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  opt_out_at      timestamptz,
  deleted_at      timestamptz,
  CONSTRAINT uq_walkin_phone_per_salon UNIQUE (business_id, phone)
);
CREATE INDEX IF NOT EXISTS idx_walkin_device_uuid
  ON public.salon_walkin_registrations(device_uuid) WHERE device_uuid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_walkin_ip_ua
  ON public.salon_walkin_registrations(ip_hash, user_agent_hash, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_walkin_phone
  ON public.salon_walkin_registrations(phone);

ALTER TABLE public.salon_walkin_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS walkin_reg_owner_select ON public.salon_walkin_registrations;
CREATE POLICY walkin_reg_owner_select ON public.salon_walkin_registrations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.businesses b
            WHERE b.id = salon_walkin_registrations.business_id
            AND b.owner_id = auth.uid())
  );

DROP POLICY IF EXISTS walkin_reg_admin_select ON public.salon_walkin_registrations;
CREATE POLICY walkin_reg_admin_select ON public.salon_walkin_registrations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('admin','superadmin'))
  );

-- ─── walkin_pending_appointments ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.walkin_pending_appointments (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id       uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  registration_id   uuid NOT NULL REFERENCES public.salon_walkin_registrations(id) ON DELETE CASCADE,
  service_id        uuid REFERENCES public.services(id) ON DELETE SET NULL,
  service_name      text NOT NULL,
  client_notes      text,
  status            text NOT NULL DEFAULT 'pending_assignment'
    CHECK (status IN ('pending_assignment', 'confirmed', 'expired', 'cancelled')),
  assigned_staff_id uuid REFERENCES public.staff(id) ON DELETE SET NULL,
  scheduled_at      timestamptz,
  appointment_id    uuid REFERENCES public.appointments(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  confirmed_at      timestamptz,
  expires_at        timestamptz NOT NULL DEFAULT (now() + interval '2 hours')
);
CREATE INDEX IF NOT EXISTS idx_pending_business_status
  ON public.walkin_pending_appointments(business_id, status)
  WHERE status = 'pending_assignment';

ALTER TABLE public.walkin_pending_appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pending_owner_crud ON public.walkin_pending_appointments;
CREATE POLICY pending_owner_crud ON public.walkin_pending_appointments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.businesses b
            WHERE b.id = walkin_pending_appointments.business_id
            AND b.owner_id = auth.uid())
  );

DROP POLICY IF EXISTS pending_admin_select ON public.walkin_pending_appointments;
CREATE POLICY pending_admin_select ON public.walkin_pending_appointments
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('admin','superadmin'))
  );

-- ─── appointments.payment_method — add CHECK including external_free ───────
-- Currently no CHECK constraint on appointments.payment_method. Add one.
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_payment_method_check;
ALTER TABLE public.appointments ADD CONSTRAINT appointments_payment_method_check
  CHECK (payment_method IS NULL OR payment_method IN (
    'card', 'saldo', 'oxxo', 'cash', 'cash_direct', 'external_free'
  ));

-- ─── appointments.payment_status — add 'external_collected' ────────────────
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_payment_status_check;
ALTER TABLE public.appointments ADD CONSTRAINT appointments_payment_status_check
  CHECK (payment_status IN (
    'unpaid', 'pending', 'paid', 'refunded', 'partial_refund',
    'failed', 'expired', 'refunded_to_saldo', 'deposit_forfeited',
    'external_collected'
  ));

-- ─── payments.payment_method — extend to include saldo + external_free ────
-- Note: current prod constraint is missing 'saldo' (pre-existing gap — add it here too).
ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_method_check;
ALTER TABLE public.payments ADD CONSTRAINT payments_method_check
  CHECK (payment_method IN (
    'card', 'saldo', 'oxxo', 'cash', 'cash_direct', 'external_free'
  ));

-- ─── Trigger: set free_tier_started_at on first appointment ─────────────────
CREATE OR REPLACE FUNCTION public.set_free_tier_started_at()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.businesses
  SET free_tier_started_at = now()
  WHERE id = NEW.business_id
    AND free_tier_started_at IS NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_free_tier_started ON public.appointments;
CREATE TRIGGER trg_set_free_tier_started
  AFTER INSERT ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.set_free_tier_started_at();

-- ─── pg_cron: walkin-expiry-sweeper (finding #221) ─────────────────────────
CREATE OR REPLACE FUNCTION public.expire_stale_walkin_pendings()
RETURNS void AS $$
DECLARE
  expired_row record;
BEGIN
  FOR expired_row IN
    SELECT p.id, p.business_id, p.registration_id, r.phone, b.name AS business_name
    FROM public.walkin_pending_appointments p
    JOIN public.salon_walkin_registrations r ON r.id = p.registration_id
    JOIN public.businesses b ON b.id = p.business_id
    WHERE p.status = 'pending_assignment'
      AND p.expires_at < now()
  LOOP
    UPDATE public.walkin_pending_appointments
    SET status = 'expired'
    WHERE id = expired_row.id;

    INSERT INTO public.admin_alerts (category, severity, payload)
    VALUES (
      'walkin_expired',
      'warning',
      jsonb_build_object(
        'pending_id', expired_row.id,
        'business_id', expired_row.business_id,
        'business_name', expired_row.business_name,
        'client_phone', expired_row.phone
      )
    );

    INSERT INTO public.wa_notification_queue (phone, template, variables)
    VALUES (
      expired_row.phone,
      'walkin_salon_ghost',
      jsonb_build_object('business_name', expired_row.business_name)
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Unschedule existing (idempotent rerun) then schedule
DO $$
BEGIN
  PERFORM cron.unschedule('walkin-expiry-sweeper')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'walkin-expiry-sweeper');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'walkin-expiry-sweeper',
  '*/5 * * * *',
  'SELECT public.expire_stale_walkin_pendings();'
);

-- ─── app_config toggles ─────────────────────────────────────────────────────
INSERT INTO public.app_config (key, value, description_es, group_name, data_type) VALUES
  ('enable_qr_free_tier', 'false',
   'Master toggle for salon QR free-tier program (internal + external QR)',
   'qr_program', 'bool'),
  ('external_free_sat_visible', 'false',
   'Expose external_free transactions via sat-access API (default OFF per BC, pending attorney on CFF 30-B)',
   'qr_program', 'bool'),
  ('qr_shared_device_threshold', '5',
   'Max distinct phones submitted from same (ip_hash, user_agent_hash, device_uuid) in 24h before block',
   'qr_program', 'number'),
  ('qr_per_phone_rate_limit', '3',
   'Max submissions from same phone in 24h before block (prevents salon reusing one phone for fake names)',
   'qr_program', 'number'),
  ('qr_free_tier_days', '90',
   'Days after free_tier_started_at that internal QR accepts new phone registrations',
   'qr_program', 'number')
ON CONFLICT (key) DO NOTHING;
