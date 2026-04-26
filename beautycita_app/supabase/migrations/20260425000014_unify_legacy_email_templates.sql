-- =============================================================================
-- Unify legacy HTML email templates → v1 plain-text "Equipo de BeautyCita" style
-- =============================================================================
-- The 10 templates seeded by 20260318000000_html_email_templates.sql used:
--   * Custom inline-CSS HTML scaffolding (purple gradient, tables, CTA button)
--   * "Soy {rp_name} del equipo" signature (RP-named) instead of "Equipo de BeautyCita"
--   * Stale claims ("0% comisión siempre")
--   * Different tone than the v1 templates
--
-- Plus: when these run through outreach-bulk-send, buildEmailHtml() wraps the
-- already-HTML body in another HTML envelope — broken. Plain-text bodies are
-- the contract: the edge fn renders them with the BC HTML wrapper at send
-- time. Same wrapper → uniform styling across every email.
--
-- Each legacy template's intent (FAQ / objection / urgency / etc.) is
-- preserved in the new copy; only the form changes.
-- =============================================================================

-- 1. Bienvenida a BeautyCita (cold introduction, alternative to invite_cold_email)
UPDATE outreach_templates SET
  subject = '{salon_name} en BeautyCita — invitación con datos',
  body_template = E'Hola {salon_name},\n\nSomos el Equipo de BeautyCita. Les escribimos porque tenemos {interest_count} búsquedas activas de servicios como los suyos en {city} este mes — y hoy esas búsquedas terminan en otros salones.\n\nQué obtienen al registrarse:\n\n  • Calendario y reservas 24/7\n  • CRM de clientes con recordatorios automáticos\n  • Panel con métricas de rendimiento\n  • Retenciones ISR/IVA automáticas conforme al SAT\n  • Comisión 3% solo sobre las citas que les traemos por la plataforma\n  • Sus propios clientes (los que ya tenían) no pagan comisión\n\nRegistro en 60 segundos:\nhttps://beautycita.com/registro\n\nSi prefieren que los acompañemos por teléfono o WhatsApp, respondan este correo.\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Bienvenida a BeautyCita';

-- 2. ¿Cuánto cuesta? (FAQ — cost objection)
UPDATE outreach_templates SET
  subject = '{salon_name} — esto es lo que cuesta BeautyCita',
  body_template = E'Hola {salon_name},\n\nLes respondemos directo: BeautyCita no tiene mensualidad, no tiene costo de alta, no tiene permanencia.\n\nLa única comisión que cobramos es 3% sobre las citas que les traemos por la plataforma. Las citas con sus propios clientes (los que ya tenían) no pagan comisión, ni hoy ni nunca.\n\nLo que sí está incluido sin costo extra:\n\n  • Cumplimiento fiscal completo (CFDI mensual de retenciones)\n  • Procesamiento de pagos (Stripe + SPEI integrado)\n  • Calendario, CRM, panel de métricas\n  • Soporte por WhatsApp\n\nSi tienen una pregunta específica de costos, respondan este correo.\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = '¿Cuánto cuesta? (FAQ)';

-- 3. ¿Es seguro? Pagos y datos (FAQ — security)
UPDATE outreach_templates SET
  subject = '{salon_name} — así protegemos sus datos y su dinero',
  body_template = E'Hola {salon_name},\n\nUstedes preguntaron por seguridad. Resumen honesto:\n\nDatos de sus clientes:\n  • Cifrado en tránsito y en reposo\n  • Cumplimos LFPDPPP (Ley Federal de Protección de Datos)\n  • Ustedes son los responsables del tratamiento; nosotros los encargados\n\nDinero:\n  • Procesamos vía Stripe (PCI Level 1) y SPEI directo\n  • Sus pagos llegan a la CLABE que ustedes nos indican\n  • Retenemos ISR/IVA conforme al SAT y se las acreditamos en CFDI mensual\n  • Reconciliación contable con su contador, sin papeleo manual\n\nSi quieren ver el aviso de privacidad o el contrato antes de registrarse:\nhttps://beautycita.com/privacidad\n\nCualquier duda específica, respondan este correo.\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = '¿Es seguro? Pagos y datos (FAQ)';

-- 4. Ya tengo sistema (FAQ — switching/competitive)
UPDATE outreach_templates SET
  subject = '{salon_name} — ¿su sistema actual hace esto?',
  body_template = E'Hola {salon_name},\n\nNos imaginamos que ya tienen una forma de manejar el salón — calendario en papel, WhatsApp, o algún software como Vagaro o Fresha.\n\nNo les estamos pidiendo que cambien todo. Pueden tener BeautyCita en paralelo, sin tocar su sistema actual.\n\nLa diferencia es lo que reciben sin cambiar nada:\n\n  • Citas nuevas que vienen de búsquedas en BeautyCita (en {city} hay demanda activa)\n  • CFDI mensual de retenciones, listo para su contador\n  • Recordatorios automáticos por WhatsApp a sus clientes\n\nSi después de un mes no les sirve, lo dejan y ya. Sin costo de salida, sin permanencia.\n\n¿Lo prueban?\nhttps://beautycita.com/registro\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Ya tengo sistema (FAQ)';

-- 5. ¿Cómo me encuentran? (FAQ — discovery / how clients find them)
UPDATE outreach_templates SET
  subject = '{salon_name} — así te descubren las clientas en BeautyCita',
  body_template = E'Hola {salon_name},\n\nUstedes preguntaron cómo las clientas los encuentran. Respuesta directa:\n\n  1. La clienta abre BeautyCita y elige el servicio (corte, manicure, etc.)\n  2. La app calcula los mejores 3 salones cercanos según rating, distancia y disponibilidad\n  3. Si su salón cumple los criterios, aparece en esa lista de 3\n  4. La clienta tapa "Reservar" y la cita queda confirmada\n\nQué hace que aparezcan más arriba:\n\n  • Portafolio con al menos 5 fotos antes/después\n  • Horario configurado y actualizado\n  • Servicios con precio y duración visibles\n  • Buenas reseñas de clientes anteriores\n\nLos salones con perfil completo aparecen en el top 3 de búsquedas relevantes en su zona. Sin pago por posicionamiento — el ranking es por calidad de perfil + cercanía.\n\nRegistro en 60 segundos:\nhttps://beautycita.com/registro\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = '¿Cómo me encuentran? (FAQ)';

-- 6. Cumplimiento fiscal gratis (FAQ — tax)
UPDATE outreach_templates SET
  subject = '{salon_name} — cumplimiento fiscal sin costo extra',
  body_template = E'Hola {salon_name},\n\nSabemos que el SAT está apretando con las plataformas digitales. La reforma fiscal 2026 obliga a las plataformas a retener ISR (2.5%) e IVA (8%) sobre cada cobro electrónico, y a emitir el CFDI de retenciones mensual.\n\nEsto es lo que hacemos por ustedes, sin costo adicional:\n\n  • Calculamos y retenemos ISR + IVA en cada cobro\n  • Generamos el CFDI mensual y se lo entregamos a su contador\n  • Reportamos al SAT en su nombre\n  • Dashboard fiscal en tiempo real\n\nUstedes solo necesitan tener su RFC al día. Lo demás corre por nuestra cuenta.\n\nSi ya operan en informalidad y quieren formalizarse, también podemos orientarlos en el alta SAT.\n\nRegistro en 60 segundos:\nhttps://beautycita.com/registro\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Cumplimiento fiscal gratis (FAQ)';

-- 7. Seguimiento post-visita (followup after RP visit)
UPDATE outreach_templates SET
  subject = '{salon_name} — fue un gusto conocernos',
  body_template = E'Hola {salon_name},\n\nFue un gusto pasar a saludarlos. Como mencionamos, BeautyCita está abierto cuando ustedes quieran activarlo — sin costo, sin permanencia.\n\nSi después de pensarlo tienen preguntas, respondan este correo. Si decidieron que no es para ustedes en este momento, también está bien — los dejamos en paz.\n\nSi quieren empezar:\nhttps://beautycita.com/registro\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Seguimiento post-visita';

-- 8. Resultados reales (social proof)
UPDATE outreach_templates SET
  subject = '{salon_name} — un salón parecido al suyo, 30 días después',
  body_template = E'Hola {salon_name},\n\nPara que vean qué pasa cuando un salón en {city} entra a BeautyCita, les compartimos un caso reciente:\n\n  • Salón de barrio, 2 estilistas, 4 años operando\n  • Antes: ~12 citas/semana de clientes recurrentes\n  • 30 días después de unirse: 18 citas/semana (+50%), de las cuales 6 son clientas nuevas que llegaron por la app\n  • Comisión total que pagaron a BeautyCita el primer mes: $540 MXN sobre $18,000 MXN de citas-app\n  • Sus clientes recurrentes siguieron pagándoles directo, sin comisión\n\nNo prometemos los mismos números. Lo que sí prometemos es que el costo de probarlo es cero — si no funciona, se dan de baja.\n\nRegistro en 60 segundos:\nhttps://beautycita.com/registro\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Resultados reales';

-- 9. Lugares limitados en tu zona (urgency — softened to remove manipulative tone)
UPDATE outreach_templates SET
  subject = '{salon_name} — algunos salones de {city} ya están dentro',
  body_template = E'Hola {salon_name},\n\nEsto no es presión — es información. Algunos salones de {city} ya empezaron a usar BeautyCita y están recibiendo las citas que la app genera en su zona.\n\nNo hay un cupo cerrado — cualquier salón con buen servicio puede entrar. Pero el ranking en BeautyCita prioriza a quienes tienen perfil completo más tiempo, y los primeros que se sumaron tienen ventaja por antigüedad de reseñas.\n\nSi les interesa estar dentro:\nhttps://beautycita.com/registro\n\nSi prefieren esperar, no pasa nada — la invitación sigue abierta.\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Lugares limitados en tu zona';

-- 10. Te extrañamos (reengagement)
UPDATE outreach_templates SET
  subject = '{salon_name} — ¿seguimos por aquí?',
  body_template = E'Hola {salon_name},\n\nLes escribimos hace un tiempo sobre BeautyCita y no recibimos respuesta. No queremos saturarlos — solo confirmar si quieren que sigamos en contacto o si prefieren que ya no les escribamos.\n\nSi siguen interesados, el alta sigue siendo gratuita:\nhttps://beautycita.com/registro\n\nSi no, simplemente respondan BAJA y los retiramos de nuestra lista. Sin resentimientos.\n\nMucho éxito con el salón en cualquier caso.\n\nSaludos,\nEquipo de BeautyCita\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE name = 'Te extrañamos';
