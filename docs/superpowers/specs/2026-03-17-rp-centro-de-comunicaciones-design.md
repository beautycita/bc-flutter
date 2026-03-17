# RP Centro de Comunicaciones — Design Spec

**Date:** 2026-03-17
**Status:** Draft
**Author:** Claude (BC's #2)

## Overview

Complete overhaul of the RP (Relaciones Publicas) panel. Replaces the current bottom-sheet salon detail with a full-screen "Centro de Comunicaciones" — a per-salon command post where the RP manages all communication, onboarding progress, and meeting scheduling. All salon contact goes through BeautyCita's identity, never the RP's personal phone/WA/email.

## Problem

The current RP panel is a single 1045-line file with a cramped bottom sheet. It exposes the salon's phone number and WhatsApp directly, meaning RPs contact salons as themselves rather than as BeautyCita. There's no communication history beyond a simple visit log, no onboarding checklist, no meeting scheduling, and no way to close out the recruitment process.

## Design Decisions

1. **Full-screen page per salon** (not bottom sheet, not tabs) — the amount of functionality demands full screen real estate. RP is on their phone in the field; one salon fills the screen.
2. **Action-first 2x2 grid** — BC WhatsApp, Email, Checklist, Agendar as big tap targets. Optimized for quick field action.
3. **Chat-style communication view** — full thread between BC and the salon with template quick-replies. Not a restricted template picker — RPs can type freely. The goal is logging, not control.
4. **Manual checklist** — the RP checks items off as they help the salon through setup. Auto-detection rejected: the DB can't know if there *should* be more services/staff. The value is the RP sitting with the salon owner and doing the work together.
5. **Meeting requests, not reminders** — meetings are sent as WA requests to the salon. The salon can approve, deny, or counter-propose a time.
6. **Cerrar Proceso** — explicit close-out with two outcomes (converted vs not converted with reason).

## Screen Architecture

### Files

```
beautycita_app/lib/screens/rp/
├── rp_shell_screen.dart          # Slimmed: map + list tabs only, tap → Centro
├── rp_centro_screen.dart         # Centro de Comunicaciones (full page per salon)
└── rp_chat_screen.dart           # Chat view (WA and Email modes)

beautycita_app/lib/providers/
└── rp_provider.dart              # Expanded with checklist, chat, meetings providers
```

### Navigation Flow

```
Map/List → tap salon → Centro de Comunicaciones (full page)
  Centro → BC WhatsApp → Chat screen (WA mode)
  Centro → Email → Chat screen (Email mode)
  Centro → Checklist → Bottom sheet with checkboxes
  Centro → Agendar → Meeting request dialog
  Centro → Cerrar Proceso → Confirmation dialog
```

## Screen 1: RP Shell (Map + List)

Slimmed down from the current 1045-line file. Keeps map tab and list tab. Removes:
- Bottom sheet salon detail (replaced by Centro)
- Visit log dialog (replaced by chat)
- Nearby unvisited sheet (keep as-is, useful for field routing)
- Phone/WA sections (gone entirely)

Tapping a salon card or map pin navigates to the Centro screen, passing the salon data.

## Screen 2: Centro de Comunicaciones

Full-screen page. Sections top to bottom:

### Header (not scrollable)
- Salon name, city/state
- Star rating + review count (from discovered_salons)
- Status badge: Sin visitar / Contactado / En onboarding / Completado
- Checklist progress badge: "3/7 requeridos"

### Action Grid (2x2)
| BC WhatsApp | Email |
|---|---|
| Green gradient, BC logo | Blue gradient |
| "Enviar como BeautyCita" | "Enviar como BeautyCita" |

| Checklist | Agendar |
|---|---|
| Outline style, shows progress | Outline style |
| "3 de 7 requeridos" | "Solicitar reunión" |

### Último Contacto
One-line preview of most recent `outreach_contact_log` entry. Shows channel icon (WA/email/visit), time ago, and summary text.

### Próxima Reunión
Next pending or confirmed meeting. Shows date/time, note, and status badge (pendiente yellow / confirmada green / rechazada red / reagendada orange). Empty state: "Sin reuniones programadas".

### Quick Links Row
Small icon buttons in a horizontal row. Only shown if data exists:
- Web (opens browser)
- Instagram (opens IG)
- Facebook (opens FB)
- Navegar (opens maps app to salon location)

These are research links for the RP to learn about the salon before contact. NOT communication channels.

### Cerrar Proceso
Red outlined button at the bottom. Separated visually (danger zone).

## Screen 3: Chat (WA / Email modes)

Full-screen page. Mode passed as parameter determines channel and visual style.

### Top Bar
- Back arrow
- BC logo (gradient circle)
- "BC WhatsApp — {salon_name}" or "Email — {salon_name}"

### Message Thread
Scrollable area showing the full conversation history for this channel.

**BC outbound messages (right-aligned):**
- Green bubbles (WA) or blue bubbles (Email)
- Timestamp + which RP sent it ("— Ana (RP)" in brand pink)
- Delivery status ticks

**Salon replies (left-aligned):**
- Gray bubbles
- Timestamp only
- Caught by `wa-incoming` edge function, logged to `outreach_contact_log`

**In-person visit logs (center, system card):**
- Gray bordered card with visit icon
- Outcome: Interesada / No interesada / Callback / Sin respuesta / Registrada
- Notes text
- RP name + timestamp

**Date separators** between messages from different days.

### Bottom Input Area

**Quick-action chips (above text input):**
- **Plantillas** — opens template picker bottom sheet
- **Registrar visita** — opens visit log dialog

**Text input:**
- Standard text field with send button
- RP types freely or fills from template

### Template Picker (bottom sheet)

Categorized sections with templates. Each template shows:
- Category header (bold)
- Template name + one-line preview
- Tap fills the text input with auto-substituted text ({salon_name}, {city}, {rp_name}, etc.)
- RP can edit before sending

**Template categories:**
- **Primera visita** — intro messages, who is BC, value prop
- **Seguimiento** — check-ins, any questions, how's it going
- **Objeciones** — responses to "ya tengo AgendaPro", "no necesito", "es caro"
- **Reunión** — request meeting, confirm, reschedule
- **Onboarding** — help with setup steps, checklist items

Templates stored in `outreach_templates` table (already exists from outreach-contact edge function). Admin-managed.

### Visit Log Dialog

Quick dialog opened from the "Registrar visita" chip:
- Contact type: In-person visit (default, since WA/email are logged automatically)
- Outcome dropdown: Interesada / No interesada / Callback / Sin respuesta / Registrada
- Notes field (optional)
- Logs as a system card in the thread + updates salon `rp_status`

### Sending Flow

1. RP types or picks template → edits if needed → taps Send
2. App calls `outreach-contact` edge function: `send_wa` or `send_email`
3. Edge function sends through BC's WA API (beautypi) or email service
4. Auto-logged in `outreach_contact_log`
5. Message appears in thread immediately (optimistic)

### Incoming Replies

- `wa-incoming` edge function catches inbound WA messages to BC's number
- Logged to `outreach_contact_log` with `direction: 'inbound'`
- Appear in thread on screen open (pull, not push)
- No real-time WebSocket for now — sufficient to refresh on screen entry

## Checklist (Bottom Sheet)

Opened from Centro's Checklist button. Manual checkboxes, RP-owned per salon.

### Required Items
1. **Datos del negocio** — name, address, phone, hours
2. **Servicios configurados** — at least 1 with price + duration
3. **Staff registrado** — at least 1 stylist
4. **Horario semanal** — weekly schedule set
5. **RFC registrado** — tax ID on file
6. **Stripe Express completado** — payment processing active
7. **Información de dispersión** — bank account for cash payouts (same account linked in Stripe Express)

### Optional Items
8. **Instagram importado** — photos/bio pulled from IG
9. **Portfolio curado** — auto-generated on registration with random theme from the 5 existing themes, pre-populated with all available data. Salon's job is to curate/edit, not build from scratch.
10. **Fotos antes/después** — before/after photos uploaded
11. **Calendario sincronizado** — Google Calendar connected
12. **Licencia de funcionamiento** — business license uploaded

### Display
- Two sections: "Requeridos" and "Opcionales" with headers
- Each item: checkbox + label + timestamp when checked ("Completado 15 Mar")
- Progress shown as "X/7 requeridos" on Centro badge
- Checked items persist in `rp_checklist` table

## Meeting Request (Dialog)

Opened from Centro's Agendar button.

### Request Flow
1. RP picks date (date picker) + time (time picker) + writes note
2. Taps "Solicitar Reunión"
3. System sends WA to salon via BC identity: "Hola {salon_name}, nos gustaría visitarte el {fecha} a las {hora} para {nota}. ¿Te funciona? Puedes responder con: Sí / No / Proponer otro horario"
4. Creates `rp_meetings` row with status `pending`
5. Shows on Centro as "Próxima Reunión" with pendiente badge

### Salon Response
- Salon replies in WA
- `wa-incoming` detects meeting-related replies (keyword matching or manual RP update)
- RP can manually update meeting status from Centro if auto-detection misses
- Statuses: pending → confirmed / denied / rescheduled
- If salon proposes different time, `salon_proposed_at` column captures it; RP can accept or counter

### Centro Display
- Shows next upcoming meeting (by date)
- Status badge color: pendiente (yellow) / confirmada (green) / rechazada (red) / reagendada (orange)
- Past meetings visible in chat thread as system messages

## Cerrar Proceso

Red outlined button at bottom of Centro. Two-path confirmation:

### Path 1: Salon IS registered on BeautyCita
- Outcome: `completed`
- Archives all communication history (data stays, just flagged)
- Sets `rp_assignments.closed_at` + `close_outcome = 'completed'`
- Removes salon from RP's active list
- RP gets conversion credit (tracked for performance metrics)

### Path 2: Salon is NOT registered
- Must select reason: No interesado / Ya tiene sistema / Cerró el negocio / No contactable / Otro (with text field)
- Outcome: `not_converted`
- Archives all communication history
- Sets `rp_assignments.closed_at` + `close_outcome = 'not_converted'` + `close_reason`
- Unassigns RP: clears `discovered_salons.assigned_rp_id`, resets `rp_status = 'unassigned'`
- Salon returns to discovered pool — available for future assignment

## Database Changes

### New Tables

**`rp_checklist`**
```
id              uuid PK
discovered_salon_id  uuid FK → discovered_salons.id
rp_user_id      uuid FK → profiles.id
item_key        text NOT NULL (e.g., 'datos_negocio', 'servicios', 'staff', etc.)
checked_at      timestamptz (NULL = unchecked)
notes           text
```
- Unique constraint: (discovered_salon_id, item_key)
- RLS: RP can CRUD own rows, admin full access

**`rp_meetings`**
```
id              uuid PK
discovered_salon_id  uuid FK → discovered_salons.id
rp_user_id      uuid FK → profiles.id
proposed_at     timestamptz NOT NULL
confirmed_at    timestamptz
salon_proposed_at timestamptz
status          text DEFAULT 'pending' CHECK (pending/confirmed/denied/rescheduled)
note            text
created_at      timestamptz DEFAULT now()
updated_at      timestamptz DEFAULT now()
```
- RLS: RP can CRUD own rows, admin full access

### Modified Tables

**`rp_assignments`** — add columns:
- `closed_at` timestamptz
- `close_outcome` text CHECK (completed/not_converted)
- `close_reason` text (required when not_converted)

### Edge Function Changes

**`outreach-contact`** — expand auth to accept `rp` role (currently admin/superadmin only). RP gets same send_wa, send_email, get_history, get_templates actions. Does NOT get admin-only actions like transcribe or upload_recording.

**`wa-incoming`** — add logic to match inbound salon messages to the correct `outreach_contact_log` thread so the chat view can display them.

### No New Edge Functions

All communication goes through the existing `outreach-contact` function. Chat history reads from `outreach_contact_log`. No new server-side code needed beyond the auth expansion and wa-incoming matching.

## Portfolio Auto-Generation

When a salon registers (via `salon-registro` or manual admin creation):
1. System assigns a random theme from the 5 existing portfolio themes
2. Auto-populates the portfolio page with all available data (name, services, staff, photos)
3. Portfolio is immediately live at `beautycita.com/p/{salon-slug}`
4. Salon can curate/edit/remove/upload through the business portal
5. RP checklist item "Portfolio curado" tracks whether the RP has walked the salon through editing their auto-generated portfolio

This is a separate concern from the Centro but noted here because the checklist references it.

## What's Removed

- Phone number display on salon detail
- Direct call button
- Personal WhatsApp button (replaced by BC WhatsApp)
- "Registrar Visita" as a standalone dialog (now integrated into chat as visit logging)
- Bottom sheet salon detail (replaced by full-screen Centro)
- `_buildPhoneSection` method in rp_shell_screen.dart
- Interest level slider (replaced by outcome dropdown in visit log)

## Performance Considerations

- Chat history: paginated, load last 50 messages on screen open, infinite scroll up for older
- Checklist: single query per salon, cached in provider
- Meetings: single query for next upcoming, no pagination needed
- Salon list: unchanged, already ordered by status
