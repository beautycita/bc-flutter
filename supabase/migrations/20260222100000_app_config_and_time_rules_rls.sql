-- ---------------------------------------------------------------------------
-- 1. Create app_config table for feature toggles and app configuration
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_config (
  id          uuid        NOT NULL DEFAULT gen_random_uuid(),
  key         text        NOT NULL UNIQUE,
  value       text        NOT NULL DEFAULT '',
  data_type   text        NOT NULL DEFAULT 'string',  -- 'string', 'number', 'bool', 'json'
  group_name  text        NOT NULL DEFAULT 'general',
  description_es text,
  updated_by  uuid        REFERENCES auth.users(id),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT app_config_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.app_config IS 'Application-wide configuration and feature toggles.';

-- RLS: anyone authenticated can read, only superadmin can write (enforced in app)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_config: authenticated read"
  ON public.app_config FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "app_config: authenticated update"
  ON public.app_config FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 2. Seed feature toggles
-- ---------------------------------------------------------------------------
INSERT INTO public.app_config (key, value, data_type, group_name, description_es) VALUES
  -- Payments
  ('enable_stripe_payments',    'true',  'bool', 'payments',     'Pagos con tarjeta via Stripe'),
  ('enable_btc_payments',       'true',  'bool', 'payments',     'Pagos con Bitcoin via BTCPay'),
  ('enable_cash_payments',      'true',  'bool', 'payments',     'Pagos en efectivo en salon'),
  ('enable_deposit_required',   'false', 'bool', 'payments',     'Requerir deposito para reservar'),

  -- Booking
  ('enable_instant_booking',    'true',  'bool', 'booking',      'Reservas instantaneas sin confirmacion del salon'),
  ('enable_time_inference',     'true',  'bool', 'booking',      'Motor de inferencia de tiempo automatico'),
  ('enable_uber_integration',   'false', 'bool', 'booking',      'Integracion con Uber para transporte'),
  ('enable_waitlist',           'false', 'bool', 'booking',      'Lista de espera cuando no hay disponibilidad'),

  -- Social
  ('enable_reviews',            'true',  'bool', 'social',       'Sistema de resenas y calificaciones'),
  ('enable_salon_chat',         'true',  'bool', 'social',       'Chat directo con salones'),
  ('enable_referrals',          'true',  'bool', 'social',       'Recomienda tu salon (invitaciones)'),

  -- Experimental
  ('enable_virtual_studio',     'false', 'bool', 'experimental', 'Estudio virtual con IA (prueba de looks)'),
  ('enable_ai_recommendations', 'false', 'bool', 'experimental', 'Recomendaciones personalizadas con IA'),
  ('enable_voice_booking',      'false', 'bool', 'experimental', 'Reservas por voz'),

  -- Platform
  ('enable_push_notifications', 'true',  'bool', 'platform',     'Notificaciones push para citas'),
  ('enable_analytics',          'true',  'bool', 'platform',     'Recopilacion de analytics anonimos'),
  ('enable_maintenance_mode',   'false', 'bool', 'platform',     'Modo mantenimiento — bloquea acceso a usuarios')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Fix time_inference_rules RLS — admins need to read ALL rules (incl. inactive)
--    and update them
-- ---------------------------------------------------------------------------

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Time inference rules: anyone can read active"
  ON public.time_inference_rules;

-- Read: authenticated users can read all rules
CREATE POLICY "time_inference_rules: authenticated read all"
  ON public.time_inference_rules FOR SELECT
  TO authenticated
  USING (true);

-- Update: authenticated users can update (superadmin enforced in app)
CREATE POLICY "time_inference_rules: authenticated update"
  ON public.time_inference_rules FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
