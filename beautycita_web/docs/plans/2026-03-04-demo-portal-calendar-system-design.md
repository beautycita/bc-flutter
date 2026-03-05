# Demo Portal + Calendar Management System Design

## Date: 2026-03-04

## Part 1: Read-Only Demo Business Portal

- Separate `/demo/*` route tree reusing business page components
- `DemoShell` with persistent "Vista de ejemplo" banner + "Crear mi salon" CTA
- `DemoBusinessProvider` returns hardcoded Salon de Sexi data (no Supabase)
- Pages accept `isDemo` flag — hides edit/write controls when true
- Landing page "Para salones" → `/demo`

## Part 2: Full Calendar Management System

- Edge Function `calendar-sync` handles all sync logic (both web and mobile are thin clients)
- New `calendar_syncs` table for OAuth tokens and sync state
- ICS export/import (RFC 5545 compliant)
- Public ICS feed URL for subscribe-based sync
- Google Calendar API v3 OAuth2, Microsoft Graph OAuth2, Apple CalDAV
- Bidirectional sync: BeautyCita = source of truth for appointments, external = source for personal blocks
- New "Calendario Externo" section in business portal (web + mobile)
