# RP Centro de Comunicaciones — Design Spec

**Date:** 2026-03-17
**Status:** Finished (trimmed 2026-04-03)
**Author:** Claude (BC's #2)

## Overview

Full-screen per-salon command post replacing the old bottom-sheet RP panel. All salon contact goes through BeautyCita's identity, never the RP's personal phone/WA/email.

## Screen Architecture

### rp_shell_screen.dart — Map + List
- Dual-view navigation (map tab with color-coded pins by rp_status, list tab grouped by status)
- Access gated by isRpProvider
- Tap salon → navigates to Centro

### rp_centro_screen.dart — Command Post
- Header: salon name, rating, status badge, checklist progress ("X/7 requeridos")
- 2x2 action grid: BC WhatsApp, Email, Checklist, Agendar
- Último Contacto section (most recent outreach log)
- Próxima Reunión with status badge (pending/confirmed/denied/rescheduled)
- Quick links row: Web, Instagram, Facebook, Maps navigation
- Cerrar Proceso: close-out with outcome (completed/not_converted) + reason

### rp_chat_screen.dart — Communication Thread
- Chat-style message thread (WA or Email mode)
- Template picker (grouped by category) with variable substitution
- Visit log quick action (outcome + notes)
- Date separators, RP attribution, system cards for visits/calls

## Checklist (Bottom Sheet)

7 required: datos_negocio, servicios, staff, horario_semanal, rfc, stripe_express, info_dispersion
5 optional: instagram, portfolio, fotos_antes_despues, calendario_sync, licencia

## Meeting Requests

RP picks date/time + note → WA sent to salon → status tracked (pending → confirmed/denied/rescheduled)

## Close-Out

- Completed: archives history, sets close_outcome, removes from active list
- Not converted: requires reason, unassigns RP, salon returns to discovered pool

## Database

- `rp_checklist` — per-salon manual checkboxes with timestamps
- `rp_meetings` — proposed_at, status, salon_proposed_at
- `rp_assignments` — with closed_at, close_outcome, close_reason columns

## Provider

`rp_provider.dart` — rpAssignedSalonsProvider, rpChecklistProvider, rpNextMeetingProvider, rpChatHistoryProvider, rpTemplatesProvider, plus mutation functions for toggle, meeting, send, close-out, admin assign/unassign.
