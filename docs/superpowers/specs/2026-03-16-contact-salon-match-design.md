# Contact Salon Match — Design Spec

**Date:** 2026-03-16
**Status:** Finished (trimmed 2026-04-03)
**Purpose:** Scan user's phone contacts against discovered/registered salons. Show matches with booking or invite actions.

---

## Privacy Model

All matching on-device. Phone list downloaded from DB, contacts never leave the device. LFPDPPP compliant.

## Level 1: In-App Contact Matching (iOS + Android)

- `phone_list` action in `outreach-discovered-salon` edge function returns compact `{phone, id, type}` pairs for MX salons
- `contact_match_service.dart` downloads list, reads contacts via `flutter_contacts`, normalizes phones, matches via HashMap
- `contact_match_provider.dart` manages state, fires background bio generation for matches
- Results shown as banner in invite experience screen ("Tus salones favoritos")
- Matched registered salons → book. Matched discovered salons → invite with pre-written Aphrodite message.

## Level 2: Android Contact Action Provider

Native Kotlin SyncAdapter registers "Book in BeautyCita" action in Android Contacts app:
- `AccountAuthenticator.kt`, `AuthenticatorService.kt`
- `SyncAdapter.kt`, `SyncService.kt`
- `ContactActionActivity.kt` — deep links to booking flow

## Files

- `lib/services/contact_match_service.dart`
- `lib/providers/contact_match_provider.dart`
- `lib/widgets/contact_match_section.dart`
- `lib/widgets/contact_salon_card.dart`
- `android/app/src/main/kotlin/com/beautycita/sync/` (5 Kotlin files)
- Edge function: `outreach-discovered-salon` action `phone_list`
