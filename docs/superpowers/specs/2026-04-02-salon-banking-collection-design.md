# Salon Banking Collection Flow — Design Spec

**Date:** 2026-04-02
**Status:** Finished (2026-04-03 — all gates enforced, admin UI complete, Stripe CLABE prefill wired)
**Author:** Claude (BC's #2)

---

## Problem

Salons can currently onboard without providing banking details. This means:
- BC can't pay them after services are delivered
- If Stripe goes down, BC has no independent payout path
- No KYC verification before money flows through the platform

## Principle

**No money in without a verified payout path.** A salon cannot accept bookings until banking info + photo ID are verified. No exceptions.

## Architecture

### DB Changes — `businesses` table

New columns:

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `clabe` | text | null | 18-digit Mexican interbank CLABE |
| `bank_name` | text | null | Auto-detected from CLABE prefix (first 3 digits) |
| `beneficiary_name` | text | null | Legal name on the bank account |
| `id_front_url` | text | null | Private URL in `salon-ids` bucket |
| `id_back_url` | text | null | Private URL in `salon-ids` bucket |
| `id_verification_status` | text | 'none' | One of: none, pending, verified, rejected |
| `id_verified_at` | timestamptz | null | Set when verification passes |
| `banking_complete` | boolean | false | True when CLABE + ID verified. Gates bookings. |

### Storage

New **private** bucket: `salon-ids`
- NOT public (unlike `user-media`)
- RLS: salon owner can upload to `{business_id}/` path, admin can read all
- Accepts: jpg, png, max 10MB per image

### Edge Function: `verify-salon-id`

**Input:** `{ business_id, id_front_url, id_back_url, beneficiary_name }`

**Process:**
1. Download both images from `salon-ids` bucket
2. Call Google Cloud Vision API for each image:
   - `DOCUMENT_TEXT_DETECTION` — OCR extraction
   - `OBJECT_LOCALIZATION` — verify it's an ID document
   - `CROP_HINTS` — check all 4 edges are visible (not cropped)
3. Validation checks:
   - Both images contain detected document/ID
   - Text is legible (OCR confidence > 0.7)
   - All 4 corners visible (crop hints don't indicate severe cropping)
   - Extracted name fuzzy-matches `beneficiary_name` (Levenshtein distance < 3, case-insensitive, accent-normalized)
4. On pass: update `businesses` set `id_verification_status = 'verified'`, `id_verified_at = now()`, `banking_complete = true`
5. On fail: update `id_verification_status = 'rejected'`, return specific `rejection_reason`

**Rejection reasons (user-facing, in Spanish):**
- `"La imagen no parece ser una identificacion oficial"`
- `"La imagen esta cortada — asegurate que se vean las 4 esquinas"`
- `"No se pudo leer el texto — toma la foto con buena iluminacion"`
- `"El nombre en la identificacion no coincide con el nombre del beneficiario"`

**Auth:** Requires authenticated user who is the business owner.

**Google Cloud Vision:** Uses `firebase-adminsdk` service account key stored as Supabase secret `GCLOUD_VISION_KEY`.

### CLABE Validation

The 18-digit CLABE encodes the bank in digits 1-3. A lookup table maps prefix → bank name:

- `002` → BANAMEX
- `012` → BBVA
- `014` → SANTANDER
- `021` → HSBC
- `030` → BAJIO
- `036` → INBURSA
- `037` → INTERACCIONES
- `042` → MIFEL
- `044` → SCOTIABANK
- `058` → BANREGIO
- `072` → BANORTE
- `106` → BANK OF AMERICA
- `127` → AZTECA
- `128` → AUTOFIN
- `130` → COMPARTAMOS
- `137` → BANCOPPEL
- `138` → ABC CAPITAL
- `166` → BANSEFI
- `646` → STP
- (+ others as needed)

Client-side: validate 18 digits, lookup bank name, display it. If prefix unknown, show "Banco no reconocido" but still allow submission.

CLABE checksum validation: digit 18 is a check digit (weighted mod 10). Validate client-side to catch typos.

### UX Flow

**Trigger:** Persistent banner at top of business dashboard when `banking_complete = false`:

> "Completa tu informacion bancaria para activar reservas y recibir pagos"
> [Completar ahora →]

**3-step inline flow (bottom sheet or full page):**

**Step 1 — Datos Bancarios:**
- CLABE input (18 digits, numeric keyboard, format as `XXX XXX XXXXXXXXXXXX` for readability)
- Bank name auto-fills from CLABE prefix (read-only display)
- Beneficiary name input (legal name exactly as it appears on the account)
- Validate: 18 digits, valid checksum, beneficiary not empty

**Step 2 — Identificacion Oficial:**
- "Toma foto del frente de tu INE/IFE" — camera or gallery picker
- "Toma foto del reverso de tu INE/IFE" — camera or gallery picker
- Client-side validation: image > 200KB (ensures enough detail for OCR), < 10MB, jpg/png format
- Preview both images before proceeding

**Step 3 — Confirmacion:**
- Summary card showing: bank name, CLABE (masked: `●●● ●●● ●●●●●●●● XXXX`), beneficiary name, both ID thumbnails
- "Verificar y Activar" button
- On tap: uploads images to `salon-ids/{business_id}/`, saves CLABE + beneficiary to `businesses`, calls `verify-salon-id` Edge Function
- Loading state during verification (may take 3-5 seconds for Vision API)
- On success: confetti/celebration, "Tu salon esta listo para recibir reservas!"
- On rejection: specific error message, "Reintentar" button, user stays on the failing step

### Booking Gate

- `find_available_slots` RPC: add check `WHERE banking_complete = true` to the business filter
- Booking flow provider: verify `banking_complete` before creating appointment
- Salon storefront page: if `banking_complete = false`, show "Este salon esta en proceso de activacion" instead of booking button
- Stripe Connect onboarding: prefill `beneficiary_name` as legal name, `clabe` as external account, skip those Stripe steps

### Stripe Connect Prefill

When salon initiates Stripe Connect (after banking is complete), the `stripe-connect-onboard` Edge Function prefills:
- `business_type: 'individual'` or `'company'` (based on RFC format — 12 chars = moral, 13 = fisica)
- `individual.first_name` / `last_name` from `beneficiary_name`
- `external_account.routing_number` from CLABE prefix (bank code)
- `external_account.account_number` from CLABE
- `business_profile.name` from `businesses.name`
- `business_profile.url` from `beautycita.com/salon/{slug}`

This means the salon owner sees most fields pre-filled in Stripe's onboarding — fewer steps, fewer errors, faster activation.

### Admin Visibility

BC admin dashboard gets:
- Banking status column in salons list (none / pending / verified / rejected)
- Filter by banking status
- Detail view shows: CLABE (full), bank name, beneficiary, ID images (viewable), verification timestamp
- Manual override: BC can mark as verified/rejected from admin panel
- Rejected salons show rejection reason

### Web Parity

The same 3-step flow is built for `beautycita_web` in the business settings/payments section. Same validation, same Edge Function, same storage bucket.

### Prerequisite: Fix Web Registration Atomicity

The web registration at `beautycita_web/lib/pages/registro_page.dart:690` does a direct `businesses` table insert, bypassing the `register-business` Edge Function that mobile uses. Mobile gets atomic staff entry + default schedule creation; web doesn't. Before building the banking flow, the web registration must be updated to call `register-business` like mobile does. This ensures all salons have consistent records regardless of how they registered.

### Migration Safety

- All new columns are nullable with defaults — no breaking change
- Existing salons with `stripe_account_id` already set: `banking_complete` stays false until they complete the flow. Their Stripe payments continue working, but new bookings are gated. **Exception:** for the 3 admin accounts, set `banking_complete = true` in the migration.
- `banking_complete` is the single source of truth for "can this salon accept bookings"
