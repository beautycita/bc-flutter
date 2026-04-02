-- =============================================================================
-- Fix feature toggles: seed missing, remove dead, fix key mismatches
-- =============================================================================

-- ── Fix key mismatches ───────────────────────────────────────────────────────

-- Chat: edge functions use enable_chat, DB has enable_salon_chat
-- Unify to enable_salon_chat (the one in DB). Fix edge functions separately.
-- But also add enable_chat pointing to same value for backwards compat:
INSERT INTO app_config (key, value, data_type, group_name, description_es)
SELECT 'enable_chat', value, 'bool', 'features', 'Habilitar sistema de chat (alias de enable_salon_chat)'
FROM app_config WHERE key = 'enable_salon_chat'
ON CONFLICT (key) DO NOTHING;

-- Google Calendar: mobile has enable_google_calendar, edge fns have enable_google_calendar_sync
-- Add both, pointing to true
INSERT INTO app_config (key, value, data_type, group_name, description_es) VALUES
  ('enable_google_calendar', 'true', 'bool', 'integrations', 'Habilitar integracion con Google Calendar'),
  ('enable_google_calendar_sync', 'true', 'bool', 'integrations', 'Habilitar sincronizacion con Google Calendar')
ON CONFLICT (key) DO NOTHING;

-- ── Seed 14 missing toggles (exist in mobile defaults but not in DB) ─────────

INSERT INTO app_config (key, value, data_type, group_name, description_es) VALUES
  ('enable_salon_registration', 'true', 'bool', 'features', 'Permitir registro de nuevos salones'),
  ('enable_aphrodite_ai', 'true', 'bool', 'ai', 'Habilitar asistente Aphrodite (copywriting AI)'),
  ('enable_eros_support', 'true', 'bool', 'ai', 'Habilitar soporte Eros AI'),
  ('enable_ai_avatars', 'true', 'bool', 'ai', 'Habilitar generacion de avatares AI'),
  ('enable_cita_express', 'true', 'bool', 'features', 'Habilitar Cita Express (reserva rapida por QR)'),
  ('enable_salon_invite', 'true', 'bool', 'features', 'Habilitar sistema de invitacion de salones'),
  ('enable_disputes', 'true', 'bool', 'features', 'Habilitar sistema de disputas y reclamos'),
  ('enable_on_demand_scrape', 'true', 'bool', 'features', 'Habilitar scraping bajo demanda de Google Maps'),
  ('enable_outreach_pipeline', 'true', 'bool', 'features', 'Habilitar pipeline de outreach a salones'),
  ('enable_screenshot_report', 'true', 'bool', 'features', 'Habilitar reporte de errores por captura de pantalla'),
  ('enable_qr_auth', 'true', 'bool', 'features', 'Habilitar autenticacion por QR (portfolio upload)'),
  ('enable_contact_match', 'true', 'bool', 'features', 'Habilitar sincronizacion de contactos con salones')
ON CONFLICT (key) DO NOTHING;

-- ── Add missing toggles for major features ───────────────────────────────────

INSERT INTO app_config (key, value, data_type, group_name, description_es) VALUES
  ('enable_gift_cards', 'true', 'bool', 'features', 'Habilitar tarjetas de regalo'),
  ('enable_marketing_automation', 'true', 'bool', 'features', 'Habilitar mensajes automatizados de marketing'),
  ('enable_loyalty', 'true', 'bool', 'features', 'Habilitar programa de puntos de lealtad')
ON CONFLICT (key) DO NOTHING;

-- ── Remove dead toggles (never checked in code) ─────────────────────────────

DELETE FROM app_config WHERE key IN (
  'enable_btc_payments',        -- never implemented
  'enable_instant_booking',     -- always true, nothing gates
  'enable_waitlist',            -- not implemented
  'enable_ai_recommendations',  -- not implemented in mobile
  'enable_voice_booking',       -- not implemented
  'enable_analytics',           -- shadowed by static constant, nothing gates
  'enable_ai_copy'              -- nothing checks it
);
