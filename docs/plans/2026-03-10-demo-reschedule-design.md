# Demo Reschedule — "The Holy Shit Moment"

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the web demo calendar's drag-and-drop reschedule functional, sending real WhatsApp messages to the demo user's verified phone showing exactly what stylists and clients would experience in production.

**Architecture:** Self-contained demo flow — no live code modification, no DB writes. New edge function sends labeled WhatsApp messages. Calendar UI overrides drop handler in demo mode. Phone verification gate ensures every demo user becomes a registered account.

**Tech Stack:** Flutter Web (beautycita_web), Supabase edge functions (Deno/TS), WhatsApp API via beautypi.

---

## The Experience

1. Salon owner visits `beautycita.com/demo/calendar`
2. Pulsing tooltip: "Arrastra una cita para reprogramar"
3. They drag an appointment to another time/stylist
4. Ghost block validates (green=valid, red=invalid) — shows system intelligence
5. They drop → 3 seconds later, WhatsApp message #1 (stylist) arrives on their phone
6. 20 seconds later, WhatsApp message #2 (client) arrives
7. Appointment visually moves in demo but reverts after 60 seconds
8. No DB writes, no real appointments affected

## Phone Verification Gate

- Before any calendar interaction, check if user is authenticated with verified phone
- If not → modal explaining the demo requires WhatsApp verification
- Verification uses existing `phone-verify` edge function → creates real account
- Phone stored in `profiles.phone` permanently (every demo user = registered user)
- Edge function reads phone from auth context (no spoofing)

## Edge Function: demo-reschedule

- Auth required (reads user's phone from profile via JWT)
- Receives: service name, client name, staff name, salon name, new date/time
- Sends message 1 immediately (stylist label)
- Waits 20 seconds
- Sends message 2 (client label)
- Uses existing WhatsApp API endpoint on beautypi
- No DB writes whatsoever

## Message Templates

### Message 1 (Stylist) — Immediate
```
⚡ *[DEMO] Mensaje para la estilista*

*BeautyCita - Cita Reagendada*
La cita de {service} con tu cliente {client} ha sido movida.

📅 Nueva fecha: {date}, {time}
📍 Salon: {salon}

Este mensaje se envia automaticamente cuando un gerente mueve una cita en el calendario.
```

### Message 2 (Client) — 20 second delay
```
⚡ *[DEMO] Mensaje para el/la cliente*

*BeautyCita - Cita Reagendada*
Tu cita de {service} ha sido reagendada.

📅 Nueva fecha: {date}, {time}
💇 Estilista: {staff}
📍 Salon: {salon}

Si no puedes asistir, contacta al salon:
📞 {phone} | 💬 WhatsApp

Este mensaje se envia automaticamente para que tu cliente siempre este informado.
```

## Calendar UI Changes (biz_calendar_page.dart)

- When `isDemo` + user has verified phone: enable drag-and-drop (currently disabled in demo)
- Override drop handler to skip Supabase update
- Call `demo-reschedule` edge function with fake appointment data
- Locally update demo appointment list in memory (UI reflects the move)
- Show shimmer success toast: "Mensajes enviados a tu WhatsApp"
- After 60 seconds, silently revert appointment to original position

## What We Don't Build

- No cross-day drag (intra-day sufficient for demo)
- No real DB writes in demo mode
- No booking detail changes (separate task for live app)
- No modifications to production reschedule flow
