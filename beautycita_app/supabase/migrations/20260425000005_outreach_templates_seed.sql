-- =============================================================================
-- Seed outreach templates v1 (Equipo de BeautyCita signature)
-- =============================================================================
-- Source: docs/outreach/templates_v1.md
-- Channels: whatsapp + email only (no SMS — Infobip not yet wired).
-- Compliance footer is auto-appended by edge fn — NOT in body_template.
-- =============================================================================

-- Deactivate prior seed (RP-signed copies); keep history intact
UPDATE outreach_templates
   SET is_active = false
 WHERE name IN (
   'BeautyCita te hace tus impuestos',
   'Sello de Empresa Socialmente Responsable',
   'Lo que la competencia no te dice',
   'El SAT viene por ti',
   'Invitacion exclusiva',
   'Mensaje WA inicial',
   'Seguimiento WA'
 );

-- ── Pipeline (invite) templates ─────────────────────────────────────────────

INSERT INTO outreach_templates
  (name, channel, subject, body_template, category, recipient_table, is_invite,
   required_variables, manual_variables, gating_rule, sort_order)
VALUES
(
  'invite_cold_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name} 👋\n\nSomos BeautyCita, la plataforma de reservas de belleza más usada en México. Queremos invitarlos a tener su perfil en la app — gratis, sin contrato, sin mensualidad.\n\nEl registro toma 60 segundos: beautycita.com/registro\n\nCualquier duda, respondan a este mensaje.\n\n— Equipo de BeautyCita',
  'invite_cold', 'discovered_salons', true,
  ARRAY['salon_name','city'], ARRAY[]::text[], NULL, 1
),
(
  'invite_cold_email',
  'email',
  '{salon_name} en BeautyCita — invitación',
  E'Hola {salon_name},\n\nSomos el Equipo de BeautyCita, la plataforma mexicana de reservas de servicios de belleza. Les escribimos porque su salón en {city} encaja con el tipo de negocios que estamos sumando esta temporada.\n\nQué obtienen al registrarse:\n\n  • Perfil público profesional en beautycita.com\n  • Reservas automáticas 24/7 (incluso fuera de horario)\n  • WhatsApp integrado para confirmar y recordar citas\n  • Pagos con tarjeta y SPEI sin que ustedes muevan un dedo\n  • Cumplimiento fiscal: emitimos los CFDI por retenciones cada mes\n  • Sin mensualidad, sin permanencia, sin costo de alta\n\nEl registro toma 60 segundos:\nhttps://beautycita.com/registro\n\nSi prefieren que los acompañemos por teléfono o WhatsApp, respondan este correo y agendamos.\n\nSaludos,\nEquipo de BeautyCita',
  'invite_cold', 'discovered_salons', true,
  ARRAY['salon_name','city'], ARRAY[]::text[], NULL, 2
),
(
  'invite_demand_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name},\n\nEste mes, {interest_count} personas en {city} buscaron servicios como los suyos en BeautyCita. Hoy esas búsquedas terminan en otros salones.\n\nActiven su perfil gratis en 60 segundos y empiecen a recibir esas citas:\nbeautycita.com/registro\n\n— Equipo de BeautyCita',
  'invite_demand', 'discovered_salons', true,
  ARRAY['salon_name','city','interest_count'], ARRAY[]::text[],
  '{"min_interest_count": 3}'::jsonb, 3
),
(
  'invite_reputation_email',
  'email',
  '{salon_name} — invitación destacada (⭐ {rating})',
  E'Hola {salon_name},\n\nSu salón tiene {rating} estrellas con {review_count} reseñas en {city}. Esa reputación es la razón por la que les estamos escribiendo personalmente.\n\nBeautyCita está construyendo el directorio de los mejores salones de México, y queremos que ustedes estén dentro desde el principio.\n\nComo salón destacado, su alta incluye:\n\n  • Posicionamiento prioritario en búsquedas\n  • Sello de salón verificado\n  • Onboarding acompañado por nuestro equipo\n  • Cero costo de alta, cero mensualidad, cero permanencia\n\nPara registrarse en 60 segundos:\nhttps://beautycita.com/registro\n\nSi prefieren que un humano los guíe, respondan este correo.\n\nSaludos,\nEquipo de BeautyCita',
  'invite_exclusive', 'discovered_salons', true,
  ARRAY['salon_name','city','rating','review_count'], ARRAY[]::text[],
  '{"min_rating": 4.5, "min_review_count": 20}'::jsonb, 4
),
(
  'invite_tax_email',
  'email',
  'Retenciones SAT 2026 — qué cambia para tu salón',
  E'Hola {salon_name},\n\nDesde 2026, los artículos 113-A LISR y 18-J LIVA obligan a las plataformas digitales en México a retener ISR (2.5%) e IVA (8%) sobre cada cobro electrónico, y a emitir el CFDI de retenciones cada mes.\n\nEsto aplica a cualquier salón que cobre con tarjeta o transferencia a través de cualquier sistema digital. La diferencia entre plataformas está en quién hace el papeleo:\n\nEn BeautyCita lo hacemos nosotros:\n\n  • Retenciones automáticas en cada cobro\n  • CFDI mensual generado y entregado a su contador\n  • Reporte al SAT en su nombre\n  • Dashboard fiscal en tiempo real\n\nNo es venta, es información. Si quieren ver cómo funciona en vivo, respondan este correo y los ponemos en contacto con alguien del equipo.\n\nSaludos,\nEquipo de BeautyCita',
  'invite_tax_help', 'discovered_salons', true,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 5
),
(
  'invite_followup_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name}, retomamos.\n\nSabemos que están ocupados. Solo confirmamos que la invitación a BeautyCita sigue abierta y el alta sigue siendo gratuita.\n\nbeautycita.com/registro\n\n¿Hay algo en lo que podamos ayudar para decidir?\n\n— Equipo de BeautyCita',
  'invite_followup', 'discovered_salons', true,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 6
),
(
  'invite_final_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name},\n\nEs el último mensaje que les enviaremos. No queremos ser molestos.\n\nSi en algún momento quieren probar BeautyCita, su lugar sigue ahí: beautycita.com/registro\n\nMucho éxito de cualquier manera.\n\n— Equipo de BeautyCita',
  'invite_final', 'discovered_salons', true,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 7
),
(
  'invite_final_email',
  'email',
  'Última invitación a BeautyCita',
  E'Hola {salon_name},\n\nEste es el último correo que les enviamos sobre BeautyCita. No queremos saturar su bandeja.\n\nSi más adelante quieren explorar la plataforma, su lugar sigue disponible y el alta sigue siendo gratuita:\nhttps://beautycita.com/registro\n\nIndependientemente de su decisión, les deseamos mucho éxito.\n\nSaludos,\nEquipo de BeautyCita',
  'invite_final', 'discovered_salons', true,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 8
);

-- ── Registered (operations) templates ───────────────────────────────────────

INSERT INTO outreach_templates
  (name, channel, subject, body_template, category, recipient_table, is_invite,
   required_variables, manual_variables, gating_rule, sort_order)
VALUES
(
  'reg_welcome_wa',
  'whatsapp',
  NULL,
  E'¡Bienvenidos a BeautyCita, {salon_name}! 🎉\n\nSu perfil ya está activo. Tres cosas rápidas para empezar a recibir citas:\n\n1) Subir al menos 5 fotos de su trabajo\n2) Activar el horario de atención\n3) Marcar sus servicios como activos\n\nCualquier cosa, responden este mensaje.\n\n— Equipo de BeautyCita',
  'registered_welcome', 'businesses', false,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 10
),
(
  'reg_welcome_email',
  'email',
  'Bienvenidos a BeautyCita, {salon_name}',
  E'Hola {salon_name},\n\nBienvenidos a BeautyCita. Su perfil ya es público en:\n{salon_url}\n\nPara que su salón empiece a recibir citas esta misma semana, recomendamos completar tres puntos:\n\n  1. Portafolio: suban al menos 5 fotos antes/después\n     Los salones con portafolio reciben hasta 3× más vistas.\n\n  2. Horario: configuren días y horas de atención\n     Sin horario, no aparecen en búsquedas.\n\n  3. Servicios: revisen precios y duraciones\n     Los precios visibles aumentan la conversión.\n\nTodo se hace desde la app o desde el panel web:\nhttps://beautycita.com/business\n\nSi necesitan ayuda con cualquiera de los pasos, respondan este correo.\n\nSaludos,\nEquipo de BeautyCita',
  'registered_welcome', 'businesses', false,
  ARRAY['salon_name','salon_url'], ARRAY[]::text[], NULL, 11
),
(
  'reg_inactive_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name},\n\nNotamos que llevan {last_booking_days} días sin recibir citas en BeautyCita. ¿Está todo bien?\n\nA veces es solo cuestión de actualizar fotos u horarios. Si quieren, revisamos juntos su perfil — respondan este mensaje y agendamos 10 minutos.\n\n— Equipo de BeautyCita',
  'registered_inactive', 'businesses', false,
  ARRAY['salon_name','last_booking_days'], ARRAY[]::text[], NULL, 12
),
(
  'reg_portfolio_email',
  'email',
  '{salon_name}, completa tu portafolio para aparecer en más búsquedas',
  E'Hola {salon_name},\n\nSu salón tiene actualmente {portfolio_count} foto(s) en su portafolio.\n\nLos datos internos de BeautyCita muestran un patrón claro:\n\n  • 0–4 fotos: bajo posicionamiento, baja conversión\n  • 5–9 fotos: posicionamiento medio\n  • 10+ fotos: aparecen en el top 3 con frecuencia\n\nPara subir fotos:\n\n  • Desde la app móvil: pestaña "Portafolio" → botón cámara\n  • Desde web: beautycita.com/business → Portafolio\n  • O si prefieren, sus estilistas pueden subir fotos directo con un código QR + PIN\n    (más info: beautycita.com/business/staff)\n\nSi quieren ayuda para producir las primeras fotos, respondan este correo.\n\nSaludos,\nEquipo de BeautyCita',
  'registered_portfolio', 'businesses', false,
  ARRAY['salon_name','portfolio_count'], ARRAY[]::text[], NULL, 13
),
(
  'reg_rfc_email',
  'email',
  '{salon_name} — confirma tu RFC para activar pagos',
  E'Hola {salon_name},\n\nPara que BeautyCita pueda procesar pagos a su nombre y emitir los CFDI mensuales de retenciones, necesitamos tener su RFC en sistema.\n\nTomarles 30 segundos:\n\n  1. Abrir la app o entrar a beautycita.com/business\n  2. Configuración → Datos fiscales\n  3. Capturar RFC + régimen fiscal\n\nUna vez registrado:\n\n  • Se activan los pagos a su CLABE\n  • Reciben su CFDI de retenciones cada mes\n  • Su salón puede aparecer con sello de salón verificado\n\nSi tienen dudas con el régimen fiscal correcto, respondan este correo y los orientamos.\n\nSaludos,\nEquipo de BeautyCita',
  'registered_rfc', 'businesses', false,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 14
),
(
  'reg_clabe_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name},\n\nPara liberar sus pagos, falta capturar la CLABE de la cuenta bancaria del salón.\n\nLo configuran en: beautycita.com/business → Pagos → Datos bancarios\n\nCualquier duda, respondan aquí.\n\n— Equipo de BeautyCita',
  'registered_banking', 'businesses', false,
  ARRAY['salon_name'], ARRAY[]::text[], NULL, 15
),
(
  'reg_feature_announce_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name} 👋\n\nAcabamos de liberar: {feature_title}\n\nDetalles aquí: {feature_url}\n\n— Equipo de BeautyCita',
  'registered_announce', 'businesses', false,
  ARRAY['salon_name'], ARRAY['feature_title','feature_url'], NULL, 16
),
(
  'reg_feature_announce_email',
  'email',
  'Nuevo en BeautyCita: {feature_title}',
  E'Hola {salon_name},\n\nQuisimos avisarles directamente: acabamos de liberar {feature_title}.\n\n{feature_summary}\n\nPueden verlo aquí:\n{feature_url}\n\nSi tienen comentarios o ideas, respondan este correo. Lo leemos.\n\nSaludos,\nEquipo de BeautyCita',
  'registered_announce', 'businesses', false,
  ARRAY['salon_name'], ARRAY['feature_title','feature_summary','feature_url'], NULL, 17
),
(
  'reg_policy_update_email',
  'email',
  'Actualización de Términos y Condiciones — efectiva {effective_date}',
  E'Hola {salon_name},\n\nLes escribimos para notificarles formalmente una actualización de los Términos y Condiciones de BeautyCita, efectiva el {effective_date}.\n\nResumen de cambios:\n\n{summary_md}\n\nEl detalle completo está en:\n{changelog_url}\n\nSi continúan utilizando BeautyCita después del {effective_date}, se entiende su aceptación de los términos actualizados. Si tienen objeciones o dudas, respondan este correo antes de esa fecha.\n\nSaludos,\nEquipo de BeautyCita',
  'registered_policy', 'businesses', false,
  ARRAY['salon_name'], ARRAY['effective_date','summary_md','changelog_url'], NULL, 18
),
(
  'reg_seasonal_wa',
  'whatsapp',
  NULL,
  E'Hola {salon_name} 🌸\n\n{occasion} se acerca. Es buen momento para revisar:\n\n  • Servicios temporada activos\n  • Disponibilidad ampliada esa semana\n  • Fotos recientes que reflejen la temporada\n\n{cta}\n\n— Equipo de BeautyCita',
  'registered_seasonal', 'businesses', false,
  ARRAY['salon_name'], ARRAY['occasion','cta'], NULL, 19
);
