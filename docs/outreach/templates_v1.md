# Outreach Templates v1 — Equipo de BeautyCita

Audience: Quetzaly + admin/superadmin senders.
Author / red-line gate: Kriket.
Channels: WhatsApp (short, direct) + Email (elaborate, formal).
Variables shown in `{curly_braces}` — substituted per recipient.
Compliance footer is **auto-appended** by the edge function; it is NOT in these bodies. See `footer_v1.md`.

---

## Variable reference

| Variable | Source | Pipeline | Registered | Fallback |
|---|---|---|---|---|
| `{salon_name}` | `business_name` / `businesses.name` | ✓ | ✓ | "tu salón" |
| `{city}` | `location_city` / `businesses.city` | ✓ | ✓ | "tu ciudad" |
| `{rating}` | `rating_average` | ✓ | ✓ | (omits sentence) |
| `{review_count}` | `rating_count` | ✓ | ✓ | (omits sentence) |
| `{interest_count}` | `discovered_salons.interest_count` | ✓ | — | "0" |
| `{owner_first_name}` | `owner.first_name` | (rare) | ✓ | "Hola" |
| `{salon_url}` | `beautycita.com/p/{slug}` | — | ✓ | — |
| `{services_count}` | count of `services` rows | — | ✓ | "0" |
| `{portfolio_count}` | count of `portfolio_photos` | — | ✓ | "0" |
| `{stylist_count}` | count of active `staff` | — | ✓ | "0" |
| `{last_booking_days}` | days since last appointment | — | ✓ | "30+" |
| `{unsubscribe_link}` | per-recipient token URL | (footer only) | (footer only) | — |

Signature on every send: `Equipo de BeautyCita`. No personal names.

---

# A. PIPELINE (invite) templates — unregistered salons

> Cooldown: 14 days per recipient before another invite can send.

---

### A1. Cold introduction — WhatsApp

**Name:** `invite_cold_wa`
**Channel:** whatsapp
**Category:** invite_cold
**Variables required:** `{salon_name}`, `{city}`

```
Hola {salon_name} 👋

Somos BeautyCita, la plataforma de reservas de belleza más usada en México. Queremos invitarlos a tener su perfil en la app — gratis, sin contrato, sin mensualidad.

El registro toma 60 segundos: beautycita.com/registro

Cualquier duda, respondan a este mensaje.

— Equipo de BeautyCita
```

---

### A2. Cold introduction — Email

**Name:** `invite_cold_email`
**Channel:** email
**Category:** invite_cold
**Subject:** `{salon_name} en BeautyCita — invitación`
**Variables required:** `{salon_name}`, `{city}`

```
Hola {salon_name},

Somos el Equipo de BeautyCita, la plataforma mexicana de reservas de servicios de belleza. Les escribimos porque su salón en {city} encaja con el tipo de negocios que estamos sumando esta temporada.

Qué obtienen al registrarse:

  • Perfil público profesional en beautycita.com
  • Reservas automáticas 24/7 (incluso fuera de horario)
  • WhatsApp integrado para confirmar y recordar citas
  • Pagos con tarjeta y SPEI sin que ustedes muevan un dedo
  • Cumplimiento fiscal: emitimos los CFDI por retenciones cada mes
  • Sin mensualidad, sin permanencia, sin costo de alta

El registro toma 60 segundos:
https://beautycita.com/registro

Si prefieren que los acompañemos por teléfono o WhatsApp, respondan este correo y agendamos.

Saludos,
Equipo de BeautyCita
```

---

### A3. Demand-proof — WhatsApp

**Name:** `invite_demand_wa`
**Channel:** whatsapp
**Category:** invite_demand
**Variables required:** `{salon_name}`, `{city}`, `{interest_count}`

> Only sendable when `interest_count >= 3`. UI greys it out otherwise.

```
Hola {salon_name},

Este mes, {interest_count} personas en {city} buscaron servicios como los suyos en BeautyCita. Hoy esas búsquedas terminan en otros salones.

Activen su perfil gratis en 60 segundos y empiecen a recibir esas citas:
beautycita.com/registro

— Equipo de BeautyCita
```

---

### A4. Reputación / invitación destacada — Email

**Name:** `invite_reputation_email`
**Channel:** email
**Category:** invite_exclusive
**Subject:** `{salon_name} — invitación destacada (⭐ {rating})`
**Variables required:** `{salon_name}`, `{city}`, `{rating}`, `{review_count}`

> Only sendable when `rating >= 4.5` and `review_count >= 20`. UI enforces.

```
Hola {salon_name},

Su salón tiene {rating} estrellas con {review_count} reseñas en {city}. Esa reputación es la razón por la que les estamos escribiendo personalmente.

BeautyCita está construyendo el directorio de los mejores salones de México, y queremos que ustedes estén dentro desde el principio.

Como salón destacado, su alta incluye:

  • Posicionamiento prioritario en búsquedas
  • Sello de salón verificado
  • Onboarding acompañado por nuestro equipo
  • Cero costo de alta, cero mensualidad, cero permanencia

Para registrarse en 60 segundos:
https://beautycita.com/registro

Si prefieren que un humano los guíe, respondan este correo.

Saludos,
Equipo de BeautyCita
```

---

### A5. Ayuda fiscal — Email

**Name:** `invite_tax_email`
**Channel:** email
**Category:** invite_tax_help
**Subject:** Retenciones SAT 2026 — qué cambia para tu salón
**Variables required:** `{salon_name}`

```
Hola {salon_name},

Desde 2026, los artículos 113-A LISR y 18-J LIVA obligan a las plataformas digitales en México a retener ISR (2.5%) e IVA (8%) sobre cada cobro electrónico, y a emitir el CFDI de retenciones cada mes.

Esto aplica a cualquier salón que cobre con tarjeta o transferencia a través de cualquier sistema digital. La diferencia entre plataformas está en quién hace el papeleo:

En BeautyCita lo hacemos nosotros:

  • Retenciones automáticas en cada cobro
  • CFDI mensual generado y entregado a su contador
  • Reporte al SAT en su nombre
  • Dashboard fiscal en tiempo real

No es venta, es información. Si quieren ver cómo funciona en vivo, respondan este correo y los ponemos en contacto con alguien del equipo.

Saludos,
Equipo de BeautyCita
```

---

### A6. Seguimiento — WhatsApp

**Name:** `invite_followup_wa`
**Channel:** whatsapp
**Category:** invite_followup
**Variables required:** `{salon_name}`

> Sent 5–7 days after first contact. UI checks last contact.

```
Hola {salon_name}, retomamos.

Sabemos que están ocupados. Solo confirmamos que la invitación a BeautyCita sigue abierta y el alta sigue siendo gratuita.

beautycita.com/registro

¿Hay algo en lo que podamos ayudar para decidir?

— Equipo de BeautyCita
```

---

### A7. Última invitación — WhatsApp + Email

**Name (WA):** `invite_final_wa`
**Channel:** whatsapp
**Category:** invite_final
**Variables required:** `{salon_name}`

```
Hola {salon_name},

Es el último mensaje que les enviaremos. No queremos ser molestos.

Si en algún momento quieren probar BeautyCita, su lugar sigue ahí: beautycita.com/registro

Mucho éxito de cualquier manera.

— Equipo de BeautyCita
```

**Name (Email):** `invite_final_email`
**Channel:** email
**Category:** invite_final
**Subject:** Última invitación a BeautyCita

```
Hola {salon_name},

Este es el último correo que les enviamos sobre BeautyCita. No queremos saturar su bandeja.

Si más adelante quieren explorar la plataforma, su lugar sigue disponible y el alta sigue siendo gratuita:
https://beautycita.com/registro

Independientemente de su decisión, les deseamos mucho éxito.

Saludos,
Equipo de BeautyCita
```

---

# B. REGISTERED templates — onboarded salons

> No cooldown. Send freely as needed.

---

### B1. Bienvenida — WhatsApp

**Name:** `reg_welcome_wa`
**Channel:** whatsapp
**Category:** registered_welcome
**Variables required:** `{salon_name}`

```
¡Bienvenidos a BeautyCita, {salon_name}! 🎉

Su perfil ya está activo. Tres cosas rápidas para empezar a recibir citas:

1) Subir al menos 5 fotos de su trabajo
2) Activar el horario de atención
3) Marcar sus servicios como activos

Cualquier cosa, responden este mensaje.

— Equipo de BeautyCita
```

---

### B2. Bienvenida — Email

**Name:** `reg_welcome_email`
**Channel:** email
**Category:** registered_welcome
**Subject:** Bienvenidos a BeautyCita, {salon_name}
**Variables required:** `{salon_name}`, `{salon_url}`

```
Hola {salon_name},

Bienvenidos a BeautyCita. Su perfil ya es público en:
{salon_url}

Para que su salón empiece a recibir citas esta misma semana, recomendamos completar tres puntos:

  1. Portafolio: suban al menos 5 fotos antes/después
     Los salones con portafolio reciben hasta 3× más vistas.

  2. Horario: configuren días y horas de atención
     Sin horario, no aparecen en búsquedas.

  3. Servicios: revisen precios y duraciones
     Los precios visibles aumentan la conversión.

Todo se hace desde la app o desde el panel web:
https://beautycita.com/business

Si necesitan ayuda con cualquiera de los pasos, respondan este correo.

Saludos,
Equipo de BeautyCita
```

---

### B3. Salón inactivo — WhatsApp

**Name:** `reg_inactive_wa`
**Channel:** whatsapp
**Category:** registered_inactive
**Variables required:** `{salon_name}`, `{last_booking_days}`

```
Hola {salon_name},

Notamos que llevan {last_booking_days} días sin recibir citas en BeautyCita. ¿Está todo bien?

A veces es solo cuestión de actualizar fotos u horarios. Si quieren, revisamos juntos su perfil — respondan este mensaje y agendamos 10 minutos.

— Equipo de BeautyCita
```

---

### B4. Portafolio incompleto — Email

**Name:** `reg_portfolio_email`
**Channel:** email
**Category:** registered_portfolio
**Subject:** {salon_name}, completa tu portafolio para aparecer en más búsquedas
**Variables required:** `{salon_name}`, `{portfolio_count}`

```
Hola {salon_name},

Su salón tiene actualmente {portfolio_count} foto(s) en su portafolio.

Los datos internos de BeautyCita muestran un patrón claro:

  • 0–4 fotos: bajo posicionamiento, baja conversión
  • 5–9 fotos: posicionamiento medio
  • 10+ fotos: aparecen en el top 3 con frecuencia

Para subir fotos:

  • Desde la app móvil: pestaña "Portafolio" → botón cámara
  • Desde web: beautycita.com/business → Portafolio
  • O si prefieren, sus estilistas pueden subir fotos directo con un código QR + PIN
    (más info: beautycita.com/business/staff)

Si quieren ayuda para producir las primeras fotos, respondan este correo.

Saludos,
Equipo de BeautyCita
```

---

### B5. RFC pendiente — Email

**Name:** `reg_rfc_email`
**Channel:** email
**Category:** registered_rfc
**Subject:** {salon_name} — confirma tu RFC para activar pagos
**Variables required:** `{salon_name}`

```
Hola {salon_name},

Para que BeautyCita pueda procesar pagos a su nombre y emitir los CFDI mensuales de retenciones, necesitamos tener su RFC en sistema.

Tomarles 30 segundos:

  1. Abrir la app o entrar a beautycita.com/business
  2. Configuración → Datos fiscales
  3. Capturar RFC + régimen fiscal

Una vez registrado:

  • Se activan los pagos a su CLABE
  • Reciben su CFDI de retenciones cada mes
  • Su salón puede aparecer con sello de salón verificado

Si tienen dudas con el régimen fiscal correcto, respondan este correo y los orientamos.

Saludos,
Equipo de BeautyCita
```

---

### B6. CLABE / Banco pendiente — WhatsApp

**Name:** `reg_clabe_wa`
**Channel:** whatsapp
**Category:** registered_banking
**Variables required:** `{salon_name}`

```
Hola {salon_name},

Para liberar sus pagos, falta capturar la CLABE de la cuenta bancaria del salón.

Lo configuran en: beautycita.com/business → Pagos → Datos bancarios

Cualquier duda, respondan aquí.

— Equipo de BeautyCita
```

---

### B7. Anuncio de feature — WhatsApp

**Name:** `reg_feature_announce_wa`
**Channel:** whatsapp
**Category:** registered_announce
**Variables required:** `{salon_name}` + admin enters `{feature_title}` + `{feature_url}` per send

```
Hola {salon_name} 👋

Acabamos de liberar: {feature_title}

Detalles aquí: {feature_url}

— Equipo de BeautyCita
```

> Admin enters `{feature_title}` and `{feature_url}` in the bulk-send sheet before confirming. These two are NOT auto-resolved per salon — they're constants for that send. UI shows "Variables del envío (manuales)" section.

---

### B8. Anuncio de feature — Email

**Name:** `reg_feature_announce_email`
**Channel:** email
**Category:** registered_announce
**Subject:** Nuevo en BeautyCita: {feature_title}
**Variables required:** `{salon_name}` + admin enters `{feature_title}`, `{feature_summary}`, `{feature_url}` per send

```
Hola {salon_name},

Quisimos avisarles directamente: acabamos de liberar **{feature_title}**.

{feature_summary}

Pueden verlo aquí:
{feature_url}

Si tienen comentarios o ideas, respondan este correo. Lo leemos.

Saludos,
Equipo de BeautyCita
```

---

### B9. Cambio de política / ToS — Email

**Name:** `reg_policy_update_email`
**Channel:** email
**Category:** registered_policy
**Subject:** Actualización de Términos y Condiciones — efectiva {effective_date}
**Variables required:** `{salon_name}` + admin enters `{effective_date}`, `{summary_md}`, `{changelog_url}` per send

```
Hola {salon_name},

Les escribimos para notificarles formalmente una actualización de los Términos y Condiciones de BeautyCita, efectiva el {effective_date}.

Resumen de cambios:

{summary_md}

El detalle completo está en:
{changelog_url}

Si continúan utilizando BeautyCita después del {effective_date}, se entiende su aceptación de los términos actualizados. Si tienen objeciones o dudas, respondan este correo antes de esa fecha.

Saludos,
Equipo de BeautyCita
```

---

### B10. Promoción estacional — WhatsApp

**Name:** `reg_seasonal_wa`
**Channel:** whatsapp
**Category:** registered_seasonal
**Variables required:** `{salon_name}` + admin enters `{occasion}`, `{cta}` per send

```
Hola {salon_name} 🌸

{occasion} se acerca. Es buen momento para revisar:

  • Servicios temporada activos
  • Disponibilidad ampliada esa semana
  • Fotos recientes que reflejen la temporada

{cta}

— Equipo de BeautyCita
```

---

# C. Subject-line conventions (email)

- Always include `{salon_name}` somewhere in the subject when relevant.
- Never use ALL CAPS.
- Never use clickbait ("URGENTE", "ÚLTIMA OPORTUNIDAD").
- Final-touch templates explicitly say "última".

# D. WhatsApp conventions

- Max 4 short paragraphs.
- One link per message.
- No emojis on policy/legal/compliance templates.
- Light emoji (👋 🌸 🎉) on welcome/seasonal only.

# E. Anti-spam / unsolicited-message footer (auto-appended)

The edge function appends a footer to every outbound message. This is **not optional** — it satisfies our obligations under unsolicited-commercial-message regulations:

- **MX — LFPDPPP** (Ley Federal de Protección de Datos Personales): identifiable sender, basis for contact, opt-out mechanism, link to aviso de privacidad.
- **MX — PROFECO REPEP**: business-to-business messaging is out of REPEP scope, but identity + opt-out is still required by the LFPDPPP regime.
- **US — CAN-SPAM** (for any salon owner with a US email or US-resident contact): physical postal address, clear unsubscribe link, accurate sender identity, no deceptive subject lines.

Full footer spec lives in `footer_v1.md`. Reproduced below for review.

**WhatsApp footer (auto-appended):**
```

—
BeautyCita S.A. de C.V. · Plaza Caracol L27, Puerto Vallarta, Jal., MX
Te contactamos porque tu salón aparece como negocio público.
Para no recibir más mensajes, responde: BAJA
```

**Email footer (auto-appended, HTML):**
```
You are receiving this because {salon_name} is listed as a public business in our directory.
Recibes este mensaje porque {salon_name} aparece como negocio público en nuestro directorio.

BeautyCita S.A. de C.V.
Plaza Caracol Local 27, Puerto Vallarta, Jalisco, México · CP 48330
hello@beautycita.com

Para darte de baja / Unsubscribe: {unsubscribe_link}
Aviso de privacidad / Privacy notice: https://beautycita.com/privacidad
```
