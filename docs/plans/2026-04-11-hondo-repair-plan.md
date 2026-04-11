# Hondo Repair Plan — Comprehensive Audit Fixes
**Date:** 2026-04-11
**Assigned to:** Hondo (kriket box)
**Reviewed by:** Wyatt (bc-dev workstation)
**Source:** docs/audits/2026-04-11-comprehensive-audit.md

---

## Rules

1. `git pull` before every phase
2. One commit per phase: `Audit fix Phase X: <description>`
3. `git push` after every commit
4. `flutter analyze` must pass with zero errors after Dart changes
5. For edge functions: edit only, do NOT deploy (Wyatt deploys)
6. `JAVA_HOME=/usr/lib/jvm/java-21-openjdk` for any Flutter builds
7. Report what you did after each phase before moving to the next

---

## Phase 1: Critical Fixes (C1, C3)

### C1. Add idempotency key to saldo RPC calls
**File:** `beautycita_app/lib/services/supabase_client.dart`
Find `adjustSaldo()` and add a UUID idempotency key:
```dart
import 'package:uuid/uuid.dart';
// In adjustSaldo:
final idempotencyKey = const Uuid().v4();
await client.rpc('increment_saldo', params: {
  'p_user_id': userId,
  'p_amount': amount,
  'p_reason': reason,
  'p_idempotency_key': idempotencyKey,
});
```
Check if `uuid` package is in pubspec. If not, add it.

### C3. Bounds checks on Future.wait results
**Files:** `admin_provider.dart:202-211`, `admin_finance_dashboard_provider.dart:536-537`, `business_provider.dart:120-130`
Replace `results[0]` through `results[N]` with bounds-checked access:
```dart
final x = results.length > 0 ? results[0] : defaultValue;
```

**Skip C2** — iOS push is a known limitation (AltStore sideloading, no APNs cert). Not a code fix.

---

## Phase 2: Booking Flow Fixes (M1, M2, M5)

### M1+M2. Add timeouts to booking RPCs
**File:** `beautycita_app/lib/providers/booking_flow_provider.dart`
- Line ~360: `create_booking_with_financials` RPC — add `.timeout(const Duration(seconds: 15))`
- Line ~398: `create-payment-intent` edge function call — add `.timeout(const Duration(seconds: 15))`

### M5. Loading state before PaymentIntent creation
**File:** Same file, before the create-payment-intent call
Add `state = state.copyWith(isLoading: true)` or equivalent loading indicator.

**Skip M3** — Race condition between client update and webhook is inherent to Stripe's architecture. The webhook is the source of truth. Document, don't fix.

**Skip M4** — `emailVerification` state is dead code. Remove the enum value if it's unused.

---

## Phase 3: Error Handling (M6-M10)

Replace ALL `catch (_) {}` and `catch (e) {}` with proper error logging.

| File | Line(s) | Fix |
|------|---------|-----|
| `updater_service.dart` | 88, 109 | `catch (e) { debugPrint('[Updater] $e'); }` |
| `home_screen.dart` | 130 | Same pattern |
| `admin_pipeline_screen.dart` | 266, 287, 308 | Same pattern |
| `admin_salones_screen.dart` | 847, 870, 1007 | Same pattern |
| `report_problem_screen.dart` | 81 | Show error toast to user, don't swallow |

---

## Phase 4: Type Safety (M11-M13)

### M11. Unsafe cast in booking_provider.dart:57
Replace `.cast<Map<String, dynamic>>()` with:
```dart
final items = (data as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
```

### M12. DateTime.parse without try-catch (booking_provider.dart:88-89)
Wrap in try-catch:
```dart
DateTime? parsedDate;
try { parsedDate = DateTime.parse(dateStr); } catch (_) {}
```

### M13. Assumes `data['cards']` exists (payment_methods_provider.dart:104-107)
Add null check:
```dart
final cards = (data['cards'] as List?) ?? [];
```

---

## Phase 5: Web SEO + Social (M17-M21, V5)

### M17+M18+V5. Meta tags for social sharing
**File:** `beautycita_web/web/index.html`
Add after existing `<meta>` tags:
```html
<!-- Open Graph -->
<meta property="og:title" content="BeautyCita — Tu cita de belleza en segundos">
<meta property="og:description" content="Reserva servicios de belleza con un solo toque. Sin llamadas, sin espera.">
<meta property="og:image" content="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/og-image.png">
<meta property="og:url" content="https://beautycita.com">
<meta property="og:type" content="website">
<meta property="og:locale" content="es_MX">
<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="BeautyCita — Tu cita de belleza en segundos">
<meta name="twitter:description" content="Reserva servicios de belleza con un solo toque.">
<meta name="twitter:image" content="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/og-image.png">
```
NOTE: The og:image needs to be created (1200x630) and uploaded to R2. Use the brand gradient + BC logo. Wyatt will create the image.

### M19. Schema.org structured data
**File:** Same file, add before `</head>`:
```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "BeautyCita",
  "operatingSystem": "Android",
  "applicationCategory": "LifestyleApplication",
  "description": "Reserva servicios de belleza en segundos",
  "url": "https://beautycita.com",
  "offers": { "@type": "Offer", "price": "0", "priceCurrency": "MXN" }
}
</script>
```

### M20. robots.txt + sitemap.xml
**File:** `beautycita_web/web/robots.txt` (create new)
```
User-agent: *
Allow: /
Sitemap: https://beautycita.com/sitemap.xml
```

**File:** `beautycita_web/web/sitemap.xml` (create new)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://beautycita.com/</loc><priority>1.0</priority></url>
  <url><loc>https://beautycita.com/privacidad</loc><priority>0.5</priority></url>
  <url><loc>https://beautycita.com/terminos</loc><priority>0.5</priority></url>
</urlset>
```

### M21. Fix manifest.json start_url
**File:** `beautycita_web/web/manifest.json`
Change `"start_url": "."` to `"start_url": "/"`

---

## Phase 6: Viral Quick Wins (V1, V3, V4, V7)

### V1. Referral conversion tracking
**File:** `beautycita_app/supabase/functions/salon-registro/index.ts`
In the `create_account` action, when `refId` is present and the discovered salon had interest signals, log which user's invite led to this registration:
```sql
INSERT INTO referral_conversions (discovered_salon_id, referrer_user_id, registered_business_id)
SELECT ds.id, (SELECT user_id FROM salon_interest_signals WHERE discovered_salon_id = ds.id ORDER BY created_at DESC LIMIT 1), newBizId
FROM discovered_salons ds WHERE ds.id = refId
```
NOTE: This needs a `referral_conversions` table. Create a migration.

### V3. Share button on booking confirmation
**File:** `beautycita_app/lib/screens/confirmation_screen.dart`
After the success state, add a "Comparte tu cita" button that opens the system share sheet with a pre-filled message + app link.

### V4. Invite friends button on home screen
**File:** `beautycita_app/lib/screens/home_screen.dart`
Add a small floating action button or a card at the bottom of the category grid: "Invita a tu salon favorito" → navigates to invite screen.

### V7. Deep link preview for salon-registro
**File:** `beautycita_app/supabase/functions/salon-registro/index.ts`
In the GET handler that serves the HTML, add `<meta>` tags to the `<head>`:
```html
<meta property="og:title" content="Tu salon ya tiene clientes esperando — BeautyCita">
<meta property="og:description" content="Registrate gratis y empieza a recibir citas">
<meta property="og:image" content="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/og-image.png">
```

---

## Phase 7: Minor Fixes (m1, m2, m4, m8, m10)

| Item | Fix |
|------|-----|
| m1 | `notification_service.dart:271-290` — re-save token after late permission grant |
| m2 | `invite_service.dart:10-14` — add basic HTML entity encoding on input |
| m4 | `web/index.html:76` — make hero font size responsive: `clamp(2rem, 5vw, 3.6rem)` |
| m8 | `booking_flow_provider.dart:667,673` — clear `selectedResult` when clearing `serviceType` in rebook |
| m10 | `auth_provider.dart:54` — add `forceRefresh` to client portal role check |

**Skip m3** (debugPrint guarded by kDebugMode — acceptable), **m5** (accessibility is a larger effort), **m7** (web dark mode deferred), **m9** (offline caching is a major feature, not a fix).

---

## Execution Summary

| Phase | Items | Severity |
|-------|-------|----------|
| 1 | C1, C3 | 2 critical |
| 2 | M1, M2, M5 | 3 major |
| 3 | M6-M10 | 5 major |
| 4 | M11-M13 | 3 major |
| 5 | M17-M21, V5 | 5 major + 1 opportunity |
| 6 | V1, V3, V4, V7 | 4 opportunities |
| 7 | m1, m2, m4, m8, m10 | 5 minor |
| **Total** | | **28 items** |

**Skipped with justification:** C2 (iOS known limitation), M3 (Stripe architecture), M4 (dead code removal), M14 (low risk), M15 (business blocker), M16 (not critical), m3/m5/m7/m9 (deferred), V2/V6/V8-V13 (future sprints).

---

## Handoff to Hondo

Copy this prompt to the kriket box Claude (Hondo):

```
Read /home/kriket/futureBeauty/docs/plans/2026-04-11-hondo-repair-plan.md. Execute it phase by phase. Rules:
1. git pull before every phase
2. One commit per phase: "Audit fix Phase X: <description>"
3. git push after every commit
4. flutter analyze must pass with zero errors after every Dart change
5. For edge functions: edit only, do NOT deploy
6. JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 for Flutter builds
7. Report what you did after each phase before moving to the next
```
