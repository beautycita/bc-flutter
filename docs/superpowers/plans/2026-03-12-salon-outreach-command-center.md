# Salon Outreach Command Center — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified contact interface, sales email templates, call recording with transcription, and booking system detection so admin/RP users can efficiently convert discovered salons to BeautyCita users.

**Architecture:** Extends existing `discovered_salons` + `salon_outreach_log` tables with new columns. New `outreach_templates` table for sales emails. New `outreach-contact` edge function consolidates all contact channels. Booking detection runs as a Playwright daemon on beautypi (same pattern as `ig_enrichment.py`). Web admin gets a contact slide-out panel and enriched detail view.

**Tech Stack:** Supabase Edge Functions (Deno), Flutter Web (Riverpod), Playwright (Python, beautypi), OpenAI Whisper API, R2 storage, Infobip (future) / beautypi WA API (current)

**Spec:** `docs/superpowers/specs/2026-03-12-salon-outreach-command-center-design.md`

---

## Chunk 1: Database Schema + Edge Function

### Task 1: Database Migration

**Files:**
- Create: `beautycita_app/supabase/migrations/20260312000000_outreach_command_center.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Outreach templates table
CREATE TABLE IF NOT EXISTS outreach_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    channel text NOT NULL CHECK (channel IN ('email', 'whatsapp', 'sms')),
    subject text,
    body_template text NOT NULL,
    category text CHECK (category IN ('tax', 'competitive', 'exclusive', 'compliance', 'general')),
    sort_order int DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Extend salon_outreach_log
ALTER TABLE salon_outreach_log
    ADD COLUMN IF NOT EXISTS recording_url text,
    ADD COLUMN IF NOT EXISTS transcript text,
    ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES outreach_templates(id),
    ADD COLUMN IF NOT EXISTS rp_user_id uuid REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS call_duration_seconds int,
    ADD COLUMN IF NOT EXISTS subject text;

-- Extend discovered_salons
ALTER TABLE discovered_salons
    ADD COLUMN IF NOT EXISTS booking_system text,
    ADD COLUMN IF NOT EXISTS booking_url text,
    ADD COLUMN IF NOT EXISTS calendar_url text,
    ADD COLUMN IF NOT EXISTS booking_enriched_at timestamptz,
    ADD COLUMN IF NOT EXISTS email text;

-- Index for booking system filter
CREATE INDEX IF NOT EXISTS idx_discovered_salons_booking_system
    ON discovered_salons (booking_system) WHERE booking_system IS NOT NULL;

-- Index for enrichment queries
CREATE INDEX IF NOT EXISTS idx_discovered_salons_booking_enrichment
    ON discovered_salons (booking_enriched_at) WHERE website IS NOT NULL AND booking_enriched_at IS NULL;

-- RLS for outreach_templates (admin read, superadmin write)
ALTER TABLE outreach_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active templates"
    ON outreach_templates FOR SELECT
    USING (is_active = true);

CREATE POLICY "Superadmin can manage templates"
    ON outreach_templates FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'superadmin'
        )
    );

-- Seed initial email templates
INSERT INTO outreach_templates (name, channel, subject, body_template, category, sort_order) VALUES
(
    'BeautyCita te hace tus impuestos',
    'email',
    'Tu salon ya cumple con el SAT? BeautyCita lo hace por ti',
    E'Hola {salon_name},\n\nA partir de 2026, el gobierno federal exige que todas las plataformas digitales retengan impuestos automaticamente:\n\n- 8% IVA sobre cada transaccion\n- 2.5% ISR sobre cada transaccion\n\nEsto aplica a TODOS los salones que reciban pagos a traves de plataformas digitales, incluyendo Stripe, MercadoPago, y cualquier sistema de pago electronico.\n\nLa buena noticia: BeautyCita maneja todo esto automaticamente.\n\n- Generamos tus CFDIs cada mes\n- Reportamos al SAT por ti\n- Tu contador recibe todo organizado\n- Zero trabajo adicional de tu parte\n\nTus competidores que ignoren esto enfrentan multas del SAT. No esperes a que te llegue la notificacion.\n\nRegistrate en 60 segundos: beautycita.com\n\nSaludos,\n{rp_name}\nBeautyCita - Relaciones Publicas\n{rp_phone}',
    'tax',
    1
),
(
    'Sello de Empresa Socialmente Responsable',
    'email',
    'Destaca tu salon: Sello SAT de Empresa Fiscalmente Responsable',
    E'Hola {salon_name},\n\nSabias que los clientes confian mas en negocios verificados?\n\nBeautyCita ofrece el sello de "Empresa Fiscalmente Responsable" a los salones que completan sus obligaciones fiscales a traves de nuestra plataforma.\n\nEste sello aparece en tu perfil publico y demuestra a tus clientes que:\n- Emites facturas electronicas (CFDIs)\n- Cumples con tus retenciones de ISR e IVA\n- Tu negocio opera en total transparencia fiscal\n\nEn un mercado donde la mayoria opera en la informalidad, este sello te diferencia. Los clientes que buscan servicios de calidad valoran la profesionalidad.\n\nAdemas, el gobierno ofrece incentivos fiscales para empresas socialmente responsables que pueden reducir tu carga tributaria.\n\nQuieres saber mas? Responde a este correo o registrate en beautycita.com\n\nSaludos,\n{rp_name}\nBeautyCita',
    'compliance',
    2
),
(
    'Lo que la competencia no te dice',
    'email',
    'Por que salones en {city} estan dejando Vagaro y Fresha',
    E'Hola {salon_name},\n\nSi usas Vagaro, Fresha, o Booksy, hay algo que no te han dicho:\n\nA partir de 2026, TODAS las plataformas digitales en Mexico deben retener impuestos. Eso incluye la plataforma que uses actualmente. La diferencia es que ellos no estan preparados para hacerlo.\n\nBeautyCita vs la competencia:\n\n| | BeautyCita | Vagaro/Fresha |\n|---|---|---|\n| Idioma | Espanol nativo | Traduccion |\n| Reservas por WhatsApp | Si | No |\n| Pagos SPEI | Si (1%) | No |\n| Retenciones SAT | Automatico | No existe |\n| CFDIs mensuales | Incluido | No |\n| Costo de setup | $0 | $25-49 USD/mes |\n| Soporte | WhatsApp directo | Email en ingles |\n\nNo esperes a que tu plataforma actual te deje colgado con el SAT.\n\n60 segundos para registrarte: beautycita.com\n\n{rp_name}\nBeautyCita',
    'competitive',
    3
),
(
    'El SAT viene por ti',
    'email',
    'Atencion {salon_name}: nuevas obligaciones fiscales para plataformas digitales',
    E'Hola {salon_name},\n\nEsto no es alarmismo — es la ley.\n\nLos articulos 113-A, 113-B, 113-C y 113-D de la Ley del ISR, reformados para 2026, establecen que:\n\n1. TODAS las plataformas digitales deben retener ISR (2.5%) e IVA (8%) de cada transaccion\n2. Las plataformas deben emitir CFDI por retenciones cada mes\n3. Los establecimientos que no esten dados de alta seran reportados al SAT\n4. El SAT puede solicitar informacion de CUALQUIER plataforma sobre sus proveedores de servicios\n\nQue significa para tu salon?\n\nSi recibes pagos electronicos (tarjeta, transferencia, app) a traves de cualquier plataforma, estas obligado a cumplir. Las multas por incumplimiento van desde $1,000 hasta $30,000 MXN por infraccion.\n\nBeautyCita es la UNICA plataforma de belleza en Mexico que ya tiene esto implementado:\n- Retenciones automaticas\n- CFDIs generados cada mes\n- Reportes al SAT en tu nombre\n- Dashboard fiscal en tiempo real\n\nNo te arriesgues. Registrate hoy: beautycita.com\n\n{rp_name}\nBeautyCita',
    'compliance',
    4
),
(
    'Invitacion exclusiva',
    'email',
    'Invitacion especial para {salon_name} - {review_count} resenas no mienten',
    E'Hola {salon_name},\n\nNotamos que tu salon tiene {rating} estrellas con {review_count} resenas en Google Maps. Eso habla de la calidad de tu trabajo.\n\nPor eso queremos invitarte personalmente a BeautyCita, la plataforma de belleza #1 en Mexico.\n\nComo salon destacado, te ofrecemos:\n\n- Onboarding gratuito con soporte dedicado\n- Posicionamiento prioritario en resultados de busqueda\n- Perfil verificado con sello de calidad\n- Sistema de reservas inteligente (tus clientes reservan en 30 segundos)\n- Portal web profesional para tu salon (beautycita.com/p/tu-salon)\n\nYa tenemos salones en {city} usando BeautyCita. No te quedes atras.\n\nResponde a este correo o registrate en 60 segundos: beautycita.com\n\nEs un placer,\n{rp_name}\nBeautyCita - Relaciones Publicas\n{rp_phone}',
    'exclusive',
    5
),
(
    'Mensaje WA inicial',
    'whatsapp',
    NULL,
    E'Hola! Soy {rp_name} de BeautyCita, la plataforma de reservas de belleza en Mexico.\n\nVimos {salon_name} en Google Maps y nos encanto. Queremos invitarlos a unirse — el registro toma 60 segundos y es gratis.\n\nbeautycita.com\n\nTienen alguna pregunta?',
    'general',
    1
),
(
    'Seguimiento WA',
    'whatsapp',
    NULL,
    E'Hola de nuevo! Soy {rp_name} de BeautyCita.\n\nLes escribi hace unos dias sobre unirse a nuestra plataforma. {interest_count} clientes ya han buscado {salon_name} en BeautyCita.\n\nEl registro es gratis y toma 60 segundos: beautycita.com\n\nQuedo al pendiente!',
    'general',
    2
);
```

- [ ] **Step 2: Run migration on production**

```bash
ssh www-bc "docker exec -i supabase-db psql -U postgres -d postgres" < beautycita_app/supabase/migrations/20260312000000_outreach_command_center.sql
```

- [ ] **Step 3: Verify tables and columns exist**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -t -A -c \"SELECT COUNT(*) FROM outreach_templates;\""
# Expected: 7

ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -t -A -c \"SELECT column_name FROM information_schema.columns WHERE table_name = 'salon_outreach_log' AND column_name IN ('recording_url','transcript','template_id','rp_user_id','call_duration_seconds','subject') ORDER BY column_name;\""
# Expected: 6 rows
```

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/supabase/migrations/20260312000000_outreach_command_center.sql
git commit -m "feat: outreach command center schema — templates + recording + booking detection"
```

---

### Task 2: Outreach Contact Edge Function

**Files:**
- Create: `beautycita_app/supabase/functions/outreach-contact/index.ts`

**Actions:** `send_wa`, `send_email`, `send_sms`, `log_call`, `upload_recording`, `transcribe`, `get_history`, `get_templates`

- [ ] **Step 1: Create the edge function**

Key patterns to follow from `outreach-discovered-salon/index.ts`:
- Auth check via `userClient.auth.getUser()` + profile role check
- WA send via `fetch(${WA_API_URL}/api/wa/check)` then `fetch(${WA_API_URL}/api/wa/send)`
- Logging to `salon_outreach_log` table
- Feature toggle via `requireFeature()` from `_shared/check-toggle.ts`

```typescript
// outreach-contact/index.ts
// Actions: send_wa, send_email, send_sms, log_call, upload_recording, transcribe, get_history, get_templates
//
// Auth: admin or superadmin role required for all actions
// Logging: all contact actions write to salon_outreach_log
// Recording: audio uploaded to R2, transcribed via OpenAI Whisper
```

The function must:
1. Parse action from JSON body
2. Verify admin/superadmin auth (same pattern as cold_outreach)
3. For `send_wa`: check WA availability → send via beautypi API → log to outreach_log
4. For `send_email`: placeholder for Infobip (log only for now, mark channel='email')
5. For `send_sms`: placeholder for Infobip (log only for now, mark channel='sms')
6. For `log_call`: insert to outreach_log with channel='phone'/'wa_call', notes, duration, outcome
7. For `upload_recording`: accept base64 audio → upload to R2 → return URL
8. For `transcribe`: fetch audio from R2 → send to OpenAI Whisper → save transcript to outreach_log
9. For `get_history`: return all outreach_log entries for a salon, ordered by sent_at DESC
10. For `get_templates`: return active templates filtered by channel

Template variable substitution: replace `{salon_name}`, `{city}`, `{rating}`, `{review_count}`, `{rp_name}`, `{rp_phone}`, `{interest_count}`, `{booking_system}` with actual values.

- [ ] **Step 2: Deploy to production**

```bash
rsync -avz beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 3: Test send_wa action**

```bash
# Test get_templates
curl -s -X POST https://beautycita.com/supabase/functions/v1/outreach-contact \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"action":"get_templates","channel":"whatsapp"}' | python3 -m json.tool

# Test get_history for a known salon
curl -s -X POST https://beautycita.com/supabase/functions/v1/outreach-contact \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"action":"get_history","discovered_salon_id":"<SALON_UUID>"}' | python3 -m json.tool
```

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/supabase/functions/outreach-contact/
git commit -m "feat: outreach-contact edge function — unified contact channels + templates + recording"
```

---

## Chunk 2: Web Admin — Contact Panel + Detail Enrichment

### Task 3: Outreach Contact Provider

**Files:**
- Create: `beautycita_web/lib/providers/outreach_contact_provider.dart`

Provides:
- `outreachTemplatesProvider` — fetches templates by channel from edge function
- `salonOutreachHistoryProvider(salonId)` — fetches contact history for a salon
- `OutreachContactService` — static methods: `sendWa()`, `sendEmail()`, `sendSms()`, `logCall()`, `uploadRecording()`

- [ ] **Step 1: Create the provider**

```dart
// outreach_contact_provider.dart
//
// Models: OutreachTemplate, OutreachLogEntry
// Providers: outreachTemplatesProvider, salonOutreachHistoryProvider(String salonId)
// Service: OutreachContactService with static methods calling outreach-contact edge function
```

`OutreachTemplate` model fields: `id, name, channel, subject, bodyTemplate, category, sortOrder`

`OutreachLogEntry` model fields: `id, discoveredSalonId, channel, recipientPhone, messageText, subject, interestCount, sentAt, notes, outcome, rpUserId, rpName, recordingUrl, transcript, callDurationSeconds, templateId`

`salonOutreachHistoryProvider` is a `FutureProvider.family<List<OutreachLogEntry>, String>` that calls `get_history` action.

- [ ] **Step 2: Commit**

```bash
git add beautycita_web/lib/providers/outreach_contact_provider.dart
git commit -m "feat: outreach contact provider — templates, history, send actions"
```

---

### Task 4: Contact Slide-Out Panel Widget

**Files:**
- Create: `beautycita_web/lib/widgets/contact_panel.dart`

This is the unified contact interface that opens when RP clicks "Contactar". Shows available channels based on salon's WA status, template picker, compose area, and send button.

- [ ] **Step 1: Create the contact panel**

```dart
// contact_panel.dart
//
// ContactPanel — StatefulWidget
// Props: DiscoveredSalon salon, VoidCallback onClose, VoidCallback onSent
//
// Sections:
// 1. Salon header (name, phone, WA status, email)
// 2. Channel selector tabs: WA Message | WA Call | Email | SMS | Phone Call
//    - SMS tab hidden if whatsapp_verified = true
//    - WA Call tab hidden if whatsapp_verified = false
// 3. Template picker (filtered by selected channel)
// 4. Compose area (pre-filled from template, editable)
//    - For email: subject + body
//    - For WA/SMS: body only
//    - For phone/WA call: notes field + outcome dropdown + duration field
// 5. Record button (for calls) — uses MediaRecorder API via dart:js_interop
// 6. Send/Log button
//
// State: selectedChannel, selectedTemplate, messageText, subject, isRecording, audioBlob
```

Channel visibility logic:
```dart
final channels = <ContactChannel>[
  ContactChannel.waMessage,  // always
  if (salon.waStatus == 'valid') ContactChannel.waCall,
  ContactChannel.email,      // always
  if (salon.waStatus != 'valid') ContactChannel.sms,
  ContactChannel.phoneCall,  // always
];
```

Template variable substitution (client-side preview):
```dart
String substituteVars(String template, DiscoveredSalon salon, String rpName, String rpPhone) {
  return template
    .replaceAll('{salon_name}', salon.name)
    .replaceAll('{city}', salon.city ?? '')
    .replaceAll('{rating}', salon.rating?.toStringAsFixed(1) ?? '')
    .replaceAll('{review_count}', '${salon.reviewCount ?? 0}')
    .replaceAll('{rp_name}', rpName)
    .replaceAll('{rp_phone}', rpPhone)
    .replaceAll('{interest_count}', '${salon.interestSignals}')
    .replaceAll('{booking_system}', salon.bookingSystem ?? 'ninguno');
}
```

- [ ] **Step 2: Add audio recording via JS interop**

For web call recording, use `dart:js_interop` with `MediaRecorder`:
```dart
// At top of contact_panel.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;
```

Record button starts `MediaRecorder` via `navigator.mediaDevices.getUserMedia()`, stops on tap, uploads base64 to edge function.

- [ ] **Step 3: Commit**

```bash
git add beautycita_web/lib/widgets/contact_panel.dart
git commit -m "feat: unified contact panel — WA, email, SMS, call with recording"
```

---

### Task 5: Wire Contact Panel to Detail View + Update Detail Panel

**Files:**
- Modify: `beautycita_web/lib/pages/admin/salon_detail_panel.dart`
- Modify: `beautycita_web/lib/pages/admin/salons_page.dart`
- Modify: `beautycita_web/lib/providers/admin_salons_provider.dart`

- [ ] **Step 1: Add booking fields to DiscoveredSalon model**

In `admin_salons_provider.dart`, add to `DiscoveredSalon`:
```dart
final String? bookingSystem;
final String? bookingUrl;
final String? calendarUrl;
final DateTime? bookingEnrichedAt;
final String? email;
```

Update `fromJson` and the select query to include:
```
booking_system, booking_url, calendar_url, booking_enriched_at, email
```

- [ ] **Step 2: Add booking system filter to Discovered tab**

In `salons_page.dart`, add to the enrichment filter dropdown:
```dart
'has_booking': 'Has Booking System',
```

In `admin_salons_provider.dart`, add filter case:
```dart
case 'has_booking':
  query = query.not('booking_system', 'is', null);
  break;
```

- [ ] **Step 3: Add booking system column to table**

In `salons_page.dart` discovered tab table columns, add after the enrichment column:
```dart
BCColumn<DiscoveredSalon>(
  id: 'booking_system',
  label: 'Booking',
  width: 80,
  cellBuilder: (salon) => salon.bookingSystem != null
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
          ),
          child: Text(
            salon.bookingSystem!,
            style: const TextStyle(color: Colors.deepPurple, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        )
      : const SizedBox.shrink(),
),
```

- [ ] **Step 4: Add contact history timeline to detail panel**

In `salon_detail_panel.dart` `DiscoveredSalonDetailContent`, add after the enrichment section and before actions:

```dart
// ── Contact History ───────────────────────────────────────
const SizedBox(height: BCSpacing.lg),
const Divider(),
const SizedBox(height: BCSpacing.md),
_SectionTitle(title: 'Historial de contacto'),
const SizedBox(height: BCSpacing.sm),
Consumer(builder: (context, ref, _) {
  final historyAsync = ref.watch(salonOutreachHistoryProvider(salon.id));
  return historyAsync.when(
    data: (entries) => entries.isEmpty
        ? Text('Sin contacto previo', style: theme.textTheme.bodySmall)
        : Column(
            children: entries.map((e) => _ContactHistoryTile(entry: e)).toList(),
          ),
    loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
    error: (e, _) => Text('Error: $e', style: theme.textTheme.bodySmall),
  );
}),
```

- [ ] **Step 5: Replace "Enviar invitacion WA" button with "Contactar" button**

Replace the single WA invite button with a "Contactar" button that opens the `ContactPanel`:
```dart
SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    onPressed: () => _openContactPanel(context, salon),
    icon: const Icon(Icons.contact_phone, size: 18),
    label: const Text('Contactar'),
  ),
),
```

The `_openContactPanel` method shows the `ContactPanel` as a dialog or side sheet.

- [ ] **Step 6: Add booking system info to detail panel enrichment section**

```dart
if (salon.bookingSystem != null) ...[
  const SizedBox(height: BCSpacing.sm),
  _InfoRow(
    icon: Icons.event_available,
    label: 'Sistema de reservas',
    value: salon.bookingSystem!,
  ),
],
if (salon.bookingUrl != null) ...[
  const SizedBox(height: BCSpacing.sm),
  _InfoRow(
    icon: Icons.open_in_new,
    label: 'Pagina de reservas',
    value: salon.bookingUrl!,
  ),
],
if (salon.calendarUrl != null) ...[
  const SizedBox(height: BCSpacing.sm),
  _InfoRow(
    icon: Icons.calendar_month,
    label: 'Calendario compartido',
    value: salon.calendarUrl!,
  ),
],
```

- [ ] **Step 7: Commit**

```bash
git add beautycita_web/lib/pages/admin/salon_detail_panel.dart \
    beautycita_web/lib/pages/admin/salons_page.dart \
    beautycita_web/lib/providers/admin_salons_provider.dart
git commit -m "feat: contact panel + booking fields + contact history in detail view"
```

---

### Task 6: Wire Outreach Page Stubs

**Files:**
- Modify: `beautycita_web/lib/pages/admin/outreach_page.dart`

- [ ] **Step 1: Replace stub buttons with real actions**

Replace the three `SnackBar("proximamente")` stubs at lines 748-792:

1. "Enviar WA" → opens `ContactPanel` with WA tab pre-selected
2. "Interesado" → calls `outreach-discovered-salon` with `action: 'invite'` (existing edge function)
3. "Importar" → calls `outreach-discovered-salon` with `action: 'import'` (existing edge function)

- [ ] **Step 2: Add RP assignment dropdown to detail panel**

Add a dropdown to assign an RP user to the salon. Updates `discovered_salons.assigned_rp_id` and `rp_status`.

```dart
// Fetch admin/superadmin users for RP dropdown
final rpUsersProvider = FutureProvider<List<({String id, String name})>>((ref) async {
  final data = await BCSupabase.client
      .from('profiles')
      .select('id, display_name')
      .inFilter('role', ['admin', 'superadmin']);
  return (data as List).map((r) => (id: r['id'] as String, name: r['display_name'] as String)).toList();
});
```

- [ ] **Step 3: Commit**

```bash
git add beautycita_web/lib/pages/admin/outreach_page.dart
git commit -m "feat: wire outreach page actions — WA, invite, import, RP assignment"
```

---

## Chunk 3: Booking System Detection Daemon

### Task 7: Booking Detection Enrichment Script

**Files:**
- Create: `beautycita-mcp/data/scraper/booking_enrichment.py`

Playwright-based daemon that crawls salon websites to detect booking systems. Follows the same architecture as `ig_enrichment.py`:
- Batch processing with configurable size
- Rate limiting (30-60s between requests)
- Context rotation
- DB reads/writes via SSH to production
- Prioritizes MX records
- Runs as systemd service on beautypi

- [ ] **Step 1: Write the detection script**

```python
#!/usr/bin/env python3
"""
BeautyCita — Booking System Detection Enrichment
Playwright daemon that crawls salon websites to detect booking platforms.

Runs as systemd service: beautycita-booking-enrichment.service
Throughput: ~500-1000 sites/day

Detection targets:
- Vagaro, Fresha, Booksy, AgendaPro, Calendly, Acuity
- Google Calendar embeds, ICS feed links
- SimplyBook.me, Setmore, MiAgenda, Appointy
- Generic "Reservar"/"Book Now" button analysis
"""

# Detection patterns:
BOOKING_PATTERNS = {
    'vagaro': {
        'urls': ['vagaro.com'],
        'scripts': ['vagaro.com/widget'],
        'iframes': ['vagaro.com'],
    },
    'fresha': {
        'urls': ['fresha.com', 'shedul.com'],
        'scripts': ['fresha.com'],
        'iframes': ['fresha.com'],
    },
    'booksy': {
        'urls': ['booksy.com'],
        'scripts': ['booksy.com'],
        'iframes': ['booksy.com'],
    },
    'agendapro': {
        'urls': ['agendapro.com'],
        'scripts': ['agendapro.com'],
        'iframes': ['agendapro.com'],
    },
    'calendly': {
        'urls': ['calendly.com'],
        'scripts': ['assets.calendly.com'],
        'iframes': ['calendly.com'],
    },
    'google_calendar': {
        'urls': ['calendar.google.com'],
        'iframes': ['calendar.google.com/calendar/embed'],
    },
    'simplybook': {
        'urls': ['simplybook.me'],
        'scripts': ['simplybook.me'],
    },
    'setmore': {
        'urls': ['setmore.com'],
        'scripts': ['setmore.com'],
    },
    'acuity': {
        'urls': ['acuityscheduling.com', 'squarespacescheduling.com'],
        'scripts': ['acuityscheduling.com'],
    },
}
```

Detection flow per page:
1. Load URL with Playwright (30s timeout)
2. Check all `<a>` hrefs for booking platform URLs
3. Check all `<script>` src attributes for booking SDKs
4. Check all `<iframe>` src for booking embeds
5. Check for Google Calendar embed/ICS patterns
6. Check for "Reservar"/"Book"/"Agendar" buttons and where they link
7. Extract booking URL and calendar URL if found
8. Write results to `discovered_salons`

- [ ] **Step 2: Create systemd service**

```bash
ssh beautypi "cat > /etc/systemd/system/beautycita-booking-enrichment.service << 'EOF'
[Unit]
Description=BeautyCita Booking System Detection
After=network-online.target

[Service]
Type=simple
User=dmyl
WorkingDirectory=/home/dmyl/beautycita-scraper/scripts
ExecStart=/home/dmyl/beautycita-scraper/venv/bin/python booking_enrichment.py
Restart=always
RestartSec=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF"
```

- [ ] **Step 3: Deploy script to beautypi and start service**

```bash
scp beautycita-mcp/data/scraper/booking_enrichment.py beautypi:~/beautycita-scraper/scripts/
ssh beautypi "sudo systemctl daemon-reload && sudo systemctl enable beautycita-booking-enrichment && sudo systemctl start beautycita-booking-enrichment"
```

- [ ] **Step 4: Verify it's running and detecting**

```bash
ssh beautypi "journalctl -u beautycita-booking-enrichment --no-pager -n 20"
# Should show: loading batch, checking URLs, writing results

ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -t -A -c \"SELECT booking_system, COUNT(*) FROM discovered_salons WHERE booking_enriched_at IS NOT NULL GROUP BY booking_system ORDER BY COUNT(*) DESC;\""
```

- [ ] **Step 5: Commit**

```bash
git add beautycita-mcp/data/scraper/booking_enrichment.py
git commit -m "feat: booking system detection daemon — detects 10+ booking platforms from salon websites"
```

---

### Task 8: Contact History Timeline Widget

**Files:**
- Create: `beautycita_web/lib/widgets/contact_history_timeline.dart`

Reusable widget showing chronological contact history for a salon.

- [ ] **Step 1: Create the timeline widget**

```dart
// contact_history_timeline.dart
//
// _ContactHistoryTile — single entry in the timeline
// Shows: channel icon, date, RP name, message preview, outcome badge
// Expandable: full message text, transcript (for calls), audio player (for recordings)
//
// Channel icons:
//   waMessage → Icons.chat (WhatsApp green)
//   waCall → Icons.phone (WhatsApp green)
//   email → Icons.email (blue)
//   sms → Icons.sms (orange)
//   phone → Icons.phone (grey)
//
// Outcome badges: 'interested', 'not_interested', 'callback', 'no_answer', 'wrong_number'
//
// Audio player: HTML5 <audio> element via HtmlElementView for recording_url
// Transcript: expandable text with copy button
```

- [ ] **Step 2: Commit**

```bash
git add beautycita_web/lib/widgets/contact_history_timeline.dart
git commit -m "feat: contact history timeline widget — channel icons, audio player, transcript"
```

---

## Chunk 4: Add `web` Package + Build & Deploy

### Task 9: Add web package dependency

**Files:**
- Modify: `beautycita_web/pubspec.yaml`

- [ ] **Step 1: Add web package for MediaRecorder API**

```bash
cd /home/bc/futureBeauty/beautycita_web && /home/bc/flutter/bin/flutter pub add web
```

- [ ] **Step 2: Verify build**

```bash
cd /home/bc/futureBeauty/beautycita_web && /home/bc/flutter/bin/flutter build web --release
```

- [ ] **Step 3: Deploy**

```bash
rsync -avz --delete --exclude sativa /home/bc/futureBeauty/beautycita_web/build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

- [ ] **Step 4: Commit all remaining changes**

```bash
git add -A
git commit -m "feat: salon outreach command center — contact panel, templates, booking detection, call recording"
```
