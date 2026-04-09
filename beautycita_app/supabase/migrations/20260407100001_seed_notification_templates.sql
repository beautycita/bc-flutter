-- =============================================================================
-- Seed notification templates for booking-confirmation and marketing automation
-- These are the DB-editable versions of previously hardcoded text (#31)
-- =============================================================================

-- Customer WA: booking confirmed
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables)
VALUES (
  'booking_confirmed', 'whatsapp', 'customer',
  '*BeautyCita - Recibo*
{{SERVICE_NAME}} con {{SALON_NAME}}
{{BOOKING_DATE}} {{BOOKING_TIME}}
Total: {{PRICE}}
Confirmacion: #{{BOOKING_ID}}',
  '*BeautyCita - Receipt*
{{SERVICE_NAME}} at {{SALON_NAME}}
{{BOOKING_DATE}} {{BOOKING_TIME}}
Total: {{PRICE}}
Confirmation: #{{BOOKING_ID}}',
  ARRAY['SERVICE_NAME', 'SALON_NAME', 'BOOKING_DATE', 'BOOKING_TIME', 'PRICE', 'BOOKING_ID']
)
ON CONFLICT (event_type, channel, recipient_type) DO NOTHING;

-- Salon WA: new booking notification
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables)
VALUES (
  'booking_confirmed', 'whatsapp', 'salon',
  '*BeautyCita - Nueva Reserva*
Cliente: {{USER_NAME}}
Servicio: {{SERVICE_NAME}}
Fecha: {{BOOKING_DATE}} {{BOOKING_TIME}}
Total: {{PRICE}}
Ref: #{{BOOKING_ID}}',
  '*BeautyCita - New Booking*
Client: {{USER_NAME}}
Service: {{SERVICE_NAME}}
Date: {{BOOKING_DATE}} {{BOOKING_TIME}}
Total: {{PRICE}}
Ref: #{{BOOKING_ID}}',
  ARRAY['USER_NAME', 'SERVICE_NAME', 'BOOKING_DATE', 'BOOKING_TIME', 'PRICE', 'BOOKING_ID']
)
ON CONFLICT (event_type, channel, recipient_type) DO NOTHING;

-- Customer WA: review request
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables)
VALUES (
  'review_request', 'whatsapp', 'customer',
  'Hola {{USER_NAME}}! Como te fue con {{SERVICE_NAME}} en {{SALON_NAME}}? Tu opinion nos ayuda mucho. Deja tu resena aqui: {{REVIEW_LINK}}',
  'Hi {{USER_NAME}}! How was your {{SERVICE_NAME}} at {{SALON_NAME}}? Your feedback helps a lot. Leave your review here: {{REVIEW_LINK}}',
  ARRAY['USER_NAME', 'SERVICE_NAME', 'SALON_NAME', 'REVIEW_LINK']
)
ON CONFLICT (event_type, channel, recipient_type) DO NOTHING;

-- Customer push: review request
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables)
VALUES (
  'review_request', 'push', 'customer',
  'Como te fue con {{SERVICE_NAME}} en {{SALON_NAME}}? Deja tu resena!',
  'How was your {{SERVICE_NAME}} at {{SALON_NAME}}? Leave a review!',
  ARRAY['SERVICE_NAME', 'SALON_NAME']
)
ON CONFLICT (event_type, channel, recipient_type) DO NOTHING;

-- Customer WA: no-show follow-up
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables)
VALUES (
  'no_show_followup', 'whatsapp', 'customer',
  'Hola {{USER_NAME}}, notamos que no pudiste asistir a tu cita de {{SERVICE_NAME}} en {{SALON_NAME}}. Si deseas reagendar, reserva aqui: {{REBOOK_LINK}}',
  'Hi {{USER_NAME}}, we noticed you missed your {{SERVICE_NAME}} appointment at {{SALON_NAME}}. If you''d like to rebook: {{REBOOK_LINK}}',
  ARRAY['USER_NAME', 'SERVICE_NAME', 'SALON_NAME', 'REBOOK_LINK']
)
ON CONFLICT (event_type, channel, recipient_type) DO NOTHING;

-- Customer push: no-show follow-up
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables)
VALUES (
  'no_show_followup', 'push', 'customer',
  'No pudiste asistir a {{SERVICE_NAME}}? Reagenda facilmente en {{SALON_NAME}}.',
  'Missed your {{SERVICE_NAME}}? Easily rebook at {{SALON_NAME}}.',
  ARRAY['SERVICE_NAME', 'SALON_NAME']
)
ON CONFLICT (event_type, channel, recipient_type) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Marketing automation feature toggle
-- ---------------------------------------------------------------------------
INSERT INTO app_config (key, value, data_type, group_name, description_es)
VALUES ('enable_marketing_automation', 'true', 'bool', 'marketing', 'Habilitar motor de marketing automatizado (cron cada 15 min)')
ON CONFLICT (key) DO NOTHING;
