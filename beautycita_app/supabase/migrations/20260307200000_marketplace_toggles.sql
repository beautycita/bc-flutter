-- Ensure ALL feature toggles exist in app_config for the superadmin panel.
-- Each toggle is a bool with a group_name and Spanish description.

INSERT INTO public.app_config (key, value, data_type, group_name, description_es) VALUES
  -- Payments
  ('enable_stripe_payments',  'true',  'bool', 'payments',     'Pagos con tarjeta via Stripe'),
  ('enable_btc_payments',     'true',  'bool', 'payments',     'Pagos con Bitcoin via BTCPay'),
  ('enable_cash_payments',    'true',  'bool', 'payments',     'Pagos en efectivo / OXXO'),
  ('enable_deposit_required', 'false', 'bool', 'payments',     'Permitir depositos obligatorios por salon'),
  -- Booking
  ('enable_instant_booking',  'true',  'bool', 'booking',      'Reserva instantanea sin confirmacion del salon'),
  ('enable_time_inference',   'true',  'bool', 'booking',      'Motor de inferencia de horario automatico'),
  ('enable_uber_integration', 'false', 'bool', 'booking',      'Integracion con Uber para transporte a citas'),
  ('enable_waitlist',         'false', 'bool', 'booking',      'Lista de espera cuando no hay disponibilidad'),
  -- Social
  ('enable_reviews',          'true',  'bool', 'social',       'Resenas y calificaciones de clientes'),
  ('enable_salon_chat',       'true',  'bool', 'social',       'Chat entre clientes y estilistas'),
  ('enable_referrals',        'true',  'bool', 'social',       'Sistema de referidos e invitaciones a salones'),
  -- Experimental
  ('enable_virtual_studio',   'false', 'bool', 'experimental', 'Estudio virtual AR para probar estilos'),
  ('enable_ai_recommendations','false','bool', 'experimental', 'Recomendaciones inteligentes con IA'),
  ('enable_voice_booking',    'false', 'bool', 'experimental', 'Reserva por voz (asistente)'),
  -- Platform
  ('enable_push_notifications','true', 'bool', 'platform',     'Notificaciones push via FCM'),
  ('enable_analytics',        'true',  'bool', 'platform',     'Rastreo de analiticas y eventos'),
  ('enable_maintenance_mode', 'false', 'bool', 'platform',     'Modo mantenimiento — bloquea acceso a no-admins'),
  -- Marketplace
  ('enable_pos',              'true',  'bool', 'marketplace',  'Punto de venta — catalogo de productos y ventas'),
  ('enable_feed',             'true',  'bool', 'marketplace',  'Feed de inspiracion — explorar fotos y showcases'),
  ('enable_portfolio',        'true',  'bool', 'marketplace',  'Portafolio publico de estilistas y salones')
ON CONFLICT (key) DO UPDATE SET
  group_name = EXCLUDED.group_name,
  description_es = EXCLUDED.description_es,
  data_type = EXCLUDED.data_type;
