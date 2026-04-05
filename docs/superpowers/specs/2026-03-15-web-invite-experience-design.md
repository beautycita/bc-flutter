# Web Invite Experience — Design Spec

**Date:** 2026-03-15
**Status:** Finished (trimmed 2026-04-03)
**Purpose:** Desktop-first salon invite experience for beautycita.com.

---

## Layout

- **Desktop (1200px+):** Immersive master-detail split. Left panel (~420px) with search + salon cards. Right panel with detail + Aphrodite bio + invite message.
- **Tablet (800-1199px):** Grid of cards, tap opens modal detail overlay.
- **Mobile (<800px):** Full-page flow mirroring mobile app.

## Entry Points

- `/client/invitar` — authenticated client sidebar nav item
- `/invitar` — public page (browse free, sending requires auth)

## Shared Backend

All edge functions identical to mobile invite:
- `outreach-discovered-salon` (list, search, invite)
- `on-demand-scrape` (Google Places)
- `aphrodite-chat` (bio + invite message generation)

## Files

- `beautycita_web/lib/pages/client/invite_page.dart` — master-detail page
- `beautycita_web/lib/pages/public/invite_public_page.dart` — public wrapper
- `beautycita_web/lib/widgets/invite/salon_list_panel.dart`
- `beautycita_web/lib/widgets/invite/salon_detail_panel.dart`
- `beautycita_web/lib/widgets/invite/invite_message_card.dart`
- `beautycita_web/lib/providers/web_invite_provider.dart`
