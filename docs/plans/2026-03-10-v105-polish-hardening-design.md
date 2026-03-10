# v1.0.5 Polish & Hardening Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Production-polish all screens, fix theme to brand gradient, wire disconnected features, sweep technical debt, ship v1.0.5.

**Architecture:** Mobile-first changes across theme, 3 screens, 1 static HTML page, 3 edge function consistency fixes, full analyzer sweep.

**Tech Stack:** Flutter/Dart, Supabase edge functions (Deno/TS), static HTML/CSS, UptimeRobot API, nginx.

---

## 1. Privacy Web Page

Static HTML at `beautycita.com/privacy`. Content mirrors the 16-section LFPDPPP Aviso de Privacidad from `legal_screens.dart`. Styled with brand gradient, responsive, Spanish only. Deployed to `/var/www/beautycita.com/bc/privacy.html` (survives web deploys). Nginx location block: `location = /privacy { alias /var/www/beautycita.com/bc/privacy.html; }`.

## 2. Theme: Rose to Brand Gradient

Default palette (Rose & Gold) updated:
- Primary: `#ec4899` (pink-500), Secondary: `#9333ea` (purple-500)
- `primaryGradient`: `[#ec4899, #9333ea, #3b82f6]` (pink → purple → blue)
- Category colors and fonts (Poppins/Nunito) stay as-is
- **CTA buttons:** Hollow/outlined (1px border, brand primary color, transparent fill). NOT gradient-filled. Similar to "Cerrar Sesion" in settings screen but using brand primary instead of red.
- **CTA tap behavior:** On press, shimmer animation runs across the button text (same ShaderMask technique as the brand text shimmer on home/splash), then navigates. Gives tactile feedback without visual noise.

## 3. System Status Screen — Live Data via UptimeRobot

Replace static mock with real monitoring data:
- New edge function `system-health` that:
  1. Calls UptimeRobot API (read-only key) to get monitor statuses
  2. Does a quick Supabase self-ping (`/rest/v1/app_config?select=key&limit=1`)
  3. Returns JSON with per-service status + uptime percentages
- Screen calls this once on load, shows real status badges
- Fallback: if edge function unreachable, show "No se pudo verificar" state
- Polish: proper loading skeleton, error state, pull-to-refresh, last-checked timestamp

## 4. Report Problem Form — Wired to Backend

Wire `_submit()` to:
- Insert into existing `contact_submissions` table (category, description, user_id, metadata)
- Fire admin push notification via existing `send-push-notification`
- Show real success/error states
- No new edge function needed — direct Supabase insert

## 5. Toggle Consistency Migration

Migrate 3 edge functions from manual `app_config` queries to `requireFeature()` helper:
- `create-product-payment` → `requireFeature("enable_pos")`
- `order-followup` → `requireFeature("enable_pos")`
- `process-no-show` → `requireFeature("enable_push_notifications")`

No new toggles or client-side changes needed.

## 6. Technical Debt Sweep

- Run `flutter analyze` on full app
- Fix all warnings: curly braces, unused imports/variables, deprecated `withOpacity` calls
- Target: 0 analyzer issues

## 7. Build & Deploy

- Build number bump: `1.0.4+50015` (Shorebird patch for Dart-only changes)
- After all passes clean: bump to `1.0.5+50016`, full deploy
- Web deploy (privacy page + any web changes)
- Edge function deploy (system-health + 3 migrated functions)
