# Salon Invite Experience — Design Spec

**Date:** 2026-03-15
**Status:** Finished (trimmed 2026-04-03)
**Purpose:** Primary user-driven salon acquisition tool. Users invite their favorite salons to BeautyCita via personalized WhatsApp messages.

---

## Core Flow

1. User opens invite screen (top nav or booking fallback when no results)
2. Browses top 20 nearby discovered salons (PostGIS weighted by proximity + rating + reviews)
3. Searches by name — if not found, on-demand Google Places scrape inserts into `discovered_salons`
4. Taps salon → detail view with Aphrodite-generated bio + personalized invite message
5. "Enviar Invitacion" triggers dual-message flow

## Dual-Message Flow

- **Message 1 (User → Salon):** Opens wa.me with Aphrodite-generated pre-filled message
- **Message 2 (Platform → Salon):** Auto-sent via beautypi WA API with business pitch + registration link

## Aphrodite Integration

- `generate_salon_bio` — 2-3 sentence bio cached in `discovered_salons.generated_bio`
- `generate_invite_message` — fresh casual WhatsApp message each time, uses user name + salon context
- Model: GPT-4o-mini via `aphrodite-chat` edge function

## Contact Matching

Scans user phone contacts against discovered & registered salons. Matched salons shown as banner at top of invite list.

## Escalating Outreach

Interest thresholds [1, 3, 5, 10, 20] trigger progressively stronger platform messages. Rate limited to 1 per salon per 48 hours.

## Database

- `user_salon_invites` table (user_id, salon_id, invite_message, platform_message_sent)
- `discovered_salons.generated_bio` column
- PostGIS RPC for nearby search

## Edge Functions

- `aphrodite-chat` — bio + invite message generation
- `outreach-discovered-salon` — list, search, invite recording
- `on-demand-scrape` — Google Places search + insert

## UI

- **Mobile**: `invite_experience_screen.dart`, `invite_salon_detail_screen.dart`, `invite_message_bubble.dart`
- **Web**: `invite_page.dart` (master-detail responsive), `invite_public_page.dart` (no auth)
- **Web registration**: `/registro` path for invited salons (pre-filled from discovered data)
