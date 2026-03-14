# Salon Outreach Command Center — Design Spec

**Date:** 2026-03-12
**Status:** Approved
**Author:** BC + Claude

## Overview

Transform the admin Discovered Salons panel into a full outreach command center. Admin and RP (public relations) users can browse enriched salons, contact them through a unified interface, track all communication history, and identify salons with existing booking systems for easier conversion.

## 1. Unified Contact Interface

Opens as a slide-out panel when admin/RP clicks "Contactar" on any discovered salon.

### Channels (smart visibility)

| Channel | Visibility Rule | Implementation |
|---------|----------------|----------------|
| WA Message | Always shown (primary) | beautypi WA API → Infobip when keys arrive |
| WA Call | Only if `whatsapp_verified = true` | Log-based: RP calls via WA, logs outcome |
| Email | Always (manual entry if no email) | Template picker + free text compose |
| SMS | Only if `whatsapp_verified = false` | Infobip (Twilio stopgap) |
| Phone Call | Always shown | Log + record: RP calls from device, records via mic |

### Contact Flow

1. RP clicks "Contactar" → contact panel slides open
2. Panel shows salon name, phone, WA status, email, last contact date
3. Channel buttons shown based on visibility rules
4. Selecting a channel opens compose/log view:
   - **WA Message**: template picker or free text → send via API
   - **WA Call**: tap to call via WA, then log duration + notes + recording
   - **Email**: template picker with variable substitution ({salon_name}, {city}, {rating}) → send
   - **SMS**: free text → send via Infobip
   - **Phone Call**: tap to initiate, record button, then log outcome + notes
5. All contact auto-logged to `salon_outreach_log`

### Voice Call Recording & Transcription

- **Record**: `MediaRecorder` API (web) captures speakerphone audio
- **Upload**: R2 at `outreach-calls/{salon_id}/{timestamp}.webm`
- **Transcribe**: Edge function → OpenAI Whisper API (Spanish, `es` hint)
- **Store**: `salon_outreach_log.transcript` + `recording_url`
- **Browse**: Play button + expandable timestamped transcript in contact timeline
- **Search**: Full-text search across transcripts

## 2. Sales Email Templates

Stored in `outreach_templates` table, admin-editable. Not canned spam — strategic sales pitches.

### Template Library

**T1: "BeautyCita te hace tus impuestos"**
- Hook: 2026 tax reform mandates digital platform compliance
- Pain: 8% IVA + 2.5% ISR retention on ALL platform transactions
- Solution: BC handles automatically — CFDIs, monthly SAT reporting, zero accounting work
- CTA: Competitors who ignore this face penalties

**T2: "Sello de Empresa Socialmente Responsable"**
- SAT compliance badge on BeautyCita profile
- Customer trust for verified businesses
- "Empresa fiscalmente responsable" virtue signal
- Government incentives for compliant businesses

**T3: "Lo que la competencia no te dice"**
- BC vs Vagaro/Fresha/Booksy: MX-native, Spanish-first, WhatsApp booking, SPEI, zero setup
- Fee comparison
- Tax withholding is coming regardless — choose a platform that handles it

**T4: "El SAT viene por ti"**
- LISR Art. 113-A/B/C/D enforcement timeline
- Penalties for unreported digital platform income
- How BC's automatic retention protects them
- Real enforcement cases

**T5: "Invitacion exclusiva"**
- For high-value targets (4.5+ rating, 100+ reviews)
- Personalized: "Vimos que {salon_name} tiene {review_count} resenas..."
- Free onboarding, dedicated support, priority listing

### Template Variables

`{salon_name}`, `{city}`, `{owner_name}`, `{rating}`, `{review_count}`, `{booking_system}`, `{rp_name}`, `{rp_phone}`

## 3. Calendar/Booking System Detection

New enrichment daemon on beautypi, modeled after `ig_enrichment.py`.

### Detection Strategy

Crawls `website` field from `discovered_salons`. Detects by:

1. **URL patterns**: vagaro.com, fresha.com, booksy.com, agendapro.com, calendly.com, acuityscheduling.com, setmore.com, simplybook.me
2. **Embedded iframes/widgets**: Vagaro embed, Fresha widget, Booksy widget, Google Calendar embed
3. **Script sources**: booking platform SDKs loaded on page
4. **Button hrefs**: "Reservar"/"Book Now" links pointing to booking platforms
5. **Google Calendar**: `calendar.google.com/calendar/embed` or `/ical/` patterns
6. **ICS feeds**: `.ics` file links
7. **Meta tags**: OpenGraph or schema.org booking indicators
8. **Mexican platforms**: AgendaPro, MiAgenda, Appointy (common in MX market)

### New Columns on `discovered_salons`

```sql
booking_system text,           -- 'vagaro', 'fresha', 'booksy', 'google_calendar', 'agendapro', 'calendly', 'custom', null
booking_url text,              -- direct booking page URL
calendar_url text,             -- shared calendar/ICS feed URL if found
booking_enriched_at timestamptz
```

### Enrichment Daemon (`booking_enrichment.py`)

- Queries `discovered_salons WHERE website IS NOT NULL AND booking_enriched_at IS NULL`
- Prioritizes MX records (same pattern as IG enrichment)
- Playwright headless: loads page, checks DOM for booking indicators
- Rate limited: 30-60s between requests, breaks between batches
- Writes results back to DB

## 4. Database Changes

### New table: `outreach_templates`

```sql
CREATE TABLE outreach_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    channel text NOT NULL,  -- 'email', 'whatsapp', 'sms'
    subject text,           -- email subject (null for WA/SMS)
    body_template text NOT NULL,  -- with {variable} placeholders
    category text,          -- 'tax', 'competitive', 'exclusive', 'compliance', 'general'
    sort_order int DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

### Alter `salon_outreach_log`

```sql
ALTER TABLE salon_outreach_log
    ADD COLUMN recording_url text,
    ADD COLUMN transcript text,
    ADD COLUMN template_id uuid REFERENCES outreach_templates(id),
    ADD COLUMN rp_user_id uuid REFERENCES auth.users(id),
    ADD COLUMN call_duration_seconds int,
    ADD COLUMN subject text;
```

### Alter `discovered_salons`

```sql
ALTER TABLE discovered_salons
    ADD COLUMN booking_system text,
    ADD COLUMN booking_url text,
    ADD COLUMN calendar_url text,
    ADD COLUMN booking_enriched_at timestamptz,
    ADD COLUMN email text;
```

## 5. Edge Functions

### New: `outreach-contact/index.ts`

Actions:
- **`send_wa`** — Send WA message (template or free text), log to outreach_log
- **`send_email`** — Send email via Infobip (Twilio stopgap), log to outreach_log
- **`send_sms`** — Send SMS via Infobip, log to outreach_log (only if not WA verified)
- **`log_call`** — Log phone/WA call with notes, duration, outcome
- **`upload_recording`** — Accept audio blob, upload to R2, trigger transcription
- **`transcribe`** — Send audio to Whisper, save transcript to outreach_log
- **`get_history`** — Return all outreach_log entries for a salon, newest first
- **`get_templates`** — Return active templates filtered by channel

### New: `booking-detection/index.ts` (optional)

On-demand booking system check for a single salon URL. Returns detected platform + booking URL. Used from admin detail panel "Check Booking System" button.

## 6. Admin Panel UI Changes

### Discovered Tab (salons_page.dart)

**New filters:**
- "Has Booking System" toggle
- Booking platform dropdown (Vagaro, Fresha, Booksy, etc.)

**Table columns** (add):
- Booking system icon/chip (if detected)

### Detail Panel (salon_detail_panel.dart)

**Enrichment section** (expand):
- Booking system badge + link
- "Import Calendar" button (if calendar_url found)
- Email field (editable)

**Contact History Timeline** (new section):
- Chronological list of all outreach_log entries
- Each entry shows: channel icon, date, message preview, outcome badge, RP name
- Call entries: play button + expandable transcript
- Expand to see full message text

**"Contactar" button** → opens unified contact slide-out panel

### Outreach Page (outreach_page.dart)

Wire existing kanban stubs to real actions:
- RP assignment per salon
- Quick contact from pipeline cards
- Bulk WA from pipeline stage

## 7. Infobip Migration Path

Current: beautypi WA API (whatsapp-web.js) + Twilio SMS
Target: Infobip for WA Business API + SMS + Email

When Infobip keys arrive:
- Swap WA send in `outreach-contact` from beautypi API to Infobip
- Swap SMS from Twilio to Infobip
- Add email sending via Infobip
- Remove beautypi WA dependency for outreach (keep for enrichment verification)

## 8. Booking System Compatibility Matrix

| Platform | Detection Method | Calendar Access | Import Strategy |
|----------|-----------------|-----------------|-----------------|
| Google Calendar | embed URL, /ical/ link | Public ICS feed | Existing `calendar-ics` import |
| Vagaro | vagaro.com URLs, embed iframe | No public API | Scrape availability from public page |
| Fresha | fresha.com URLs, widget script | No public API | Scrape availability |
| Booksy | booksy.com URLs | No public API | Scrape availability |
| AgendaPro | agendapro.com URLs | API available | API integration (MX-native) |
| Calendly | calendly.com URLs | Public ICS feed | ICS import |
| Acuity/Squarespace | acuityscheduling.com | Public ICS feed | ICS import |
| Setmore | setmore.com URLs | API available | API integration |
| SimplyBook.me | simplybook.me URLs | API available | API integration |
| Custom/None | "Reservar" button analysis | Manual | Manual onboarding |

Priority: Google Calendar + ICS-compatible platforms first (already supported). Then AgendaPro (MX market leader). Scraping for closed platforms last.
