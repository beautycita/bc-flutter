# Salon Outreach Command Center — Design Spec

**Date:** 2026-03-12
**Status:** Finished (trimmed 2026-04-03 — unimplemented items removed, scope locked to what shipped)
**Author:** BC + Claude

## Overview

Admin and RP users can browse enriched salons, contact them through a unified multi-channel interface, track communication history, and see which salons already use booking platforms.

## 1. Unified Contact Interface

Slide-out panel when admin/RP clicks "Contactar" on any discovered salon.

### Channels (smart visibility)

| Channel | Visibility Rule |
|---------|----------------|
| WA Message | Always shown (primary) — sent via beautypi WA API |
| WA Call | Only if `whatsapp_verified = true` — log-based |
| Email | Always — template picker + free text compose (logged, delivery pending Infobip) |
| SMS | Only if `whatsapp_verified = false` (logged, delivery pending Infobip) |
| Phone Call | Always — log outcome + notes |

### Contact Flow

1. RP clicks "Contactar" → contact panel slides open
2. Panel shows salon name, phone, WA status, email, last contact date
3. Channel buttons shown based on visibility rules
4. Selecting a channel opens compose/log view with template picker or free text
5. All contact auto-logged to `salon_outreach_log`

## 2. Sales Email Templates

7 pre-seeded templates in `outreach_templates` table (5 email, 2 WA):

- **"BeautyCita te hace tus impuestos"** — tax compliance hook
- **"Sello de Empresa Socialmente Responsable"** — compliance badge
- **"Lo que la competencia no te dice"** — competitive comparison
- **"El SAT viene por ti"** — tax enforcement urgency
- **"Invitacion exclusiva"** — high-value target personalization
- **"Mensaje WA inicial"** — WhatsApp greeting
- **"Seguimiento WA"** — WhatsApp follow-up

### Template Variables

`{salon_name}`, `{city}`, `{owner_name}`, `{rating}`, `{review_count}`, `{booking_system}`, `{rp_name}`, `{rp_phone}`

## 3. Booking System Detection

Python daemon (`booking_enrichment.py`) on beautypi crawls `discovered_salons.website` and detects:

- URL patterns (vagaro, fresha, booksy, agendapro, calendly, etc.)
- Embedded iframes/widgets
- Script sources, button hrefs, meta tags
- Mexican platforms (AgendaPro, MiAgenda, Appointy)

Results stored in `discovered_salons.booking_system`, `booking_url`, `calendar_url`, `booking_enriched_at`.

## 4. Database Schema

### `outreach_templates` table
name, channel, subject, body_template, category, sort_order, is_active

### `salon_outreach_log` extensions
recording_url, transcript, template_id, rp_user_id, call_duration_seconds, subject

### `discovered_salons` extensions
booking_system, booking_url, calendar_url, booking_enriched_at, email

## 5. Edge Function: `outreach-contact/index.ts`

8 actions: send_wa, send_email, send_sms, log_call, upload_recording, transcribe, get_history, get_templates. Rate limited (20 req/min). Auth-gated to admin/superadmin/RP.

## 6. UI

### Web
- **Outreach kanban page** — 5-stage pipeline (selected → outreach_sent → registered | declined | unreachable)
- **Contact panel widget** — multi-channel with template picker + variable substitution
- **Salon detail panel** — shows booking system badge + booking URL

### Mobile
- **Outreach contact sheet** — bottom sheet, multi-channel, template picker
- **RP Centro screen** — RP-specific interface with checklist + contact logging
