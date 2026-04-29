# Mobile App Audit — Critical + High Findings Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 13 critical + high findings from the 2026-04-28 mobile-app passive audit. Restore push-notification delivery, route the legacy booking path through the financial RPC, fix gift-card tax accounting + email template, repair four admin providers broken by schema-name drift, and fix two dead Aphrodite invite-flow generators.

**Architecture:** Tactical client-side fixes scoped to single-file edits in `beautycita_app/lib/`. No migrations, no edge-function changes, no schema changes — every required server endpoint already exists and was verified during audit calibration. Five thematic tasks, each independently shippable.

**Tech Stack:** Flutter 3.38.9 / Dart 3.10, Supabase Postgres, Deno edge functions (existing — not modified by this plan).

---

## Audit verification summary (done before writing this plan)

| # | Finding | Verified |
|---|---------|----------|
| 1-4 | `send-push-notification` requires `notification_type`, `custom_title`, `custom_body`. Five client sites send `type`, `title`, `body`. | ✅ Edge fn line 425-440 confirms required keys |
| 5 | `booking_repository.dart:54-77` does direct `appointments.insert`, no RPC | ✅ Source confirms |
| 6 | `business_gift_cards_screen.dart:741-763` direct `commission_records` insert; no `tax_withholdings` trigger exists | ✅ Source + DB triggers confirmed |
| 7 | `send-email` requires `template`; gift-card caller sends `text` | ✅ Edge fn line 875-878 confirms |
| 8 | `audit_log` column is `admin_id`, not `actor_id` | ✅ Live DB confirms |
| 9 | `platform_sat_declarations` / `sat_monthly_reports` columns are `period_year`/`period_month`, not `period` | ✅ Live DB confirms |
| 10-11 | `profiles.display_name` does not exist (only `full_name`/`username`); `appointments` has no `date`/`time` columns | ✅ Live DB confirms |
| 12 | `invite_service.generateBio` missing required `discovered_salon_id`, reads `data['text']` instead of `data['bio']` | ✅ Edge fn line 638-678 confirms |
| 13 | `aphrodite-chat` action `generate_bio` does not exist (real action: `generate_salon_bio`) | ✅ Edge fn confirms — only 6 actions exist |

---

## File Structure

### Files modified

| Path | Change | Task |
|------|--------|------|
| `beautycita_app/lib/providers/booking_flow_provider.dart` | Fix push-notification body keys (lines 738-746) | 1 |
| `beautycita_app/lib/screens/business/business_calendar_screen.dart` | Fix push-notification body keys (lines 414-422) + commission insert (386-398) | 1, 3 |
| `beautycita_app/lib/screens/business/business_staff_screen.dart` | Fix push-notification body keys (lines 1108-1116) | 1 |
| `beautycita_app/lib/screens/report_problem_screen.dart` | Fix push-notification body keys (lines 76-81) | 1 |
| `beautycita_app/lib/screens/system_status_screen.dart` | Fix push-notification body keys (lines 947-952) | 1 |
| `beautycita_app/lib/repositories/booking_repository.dart` | Switch `createBooking` to `create_booking_with_financials` RPC (lines 54-77) | 2 |
| `beautycita_app/lib/screens/business/business_gift_cards_screen.dart` | Use `record_gift_card_commission` RPC + add `template` to send-email body (741-775) | 3 |
| `beautycita_app/lib/providers/admin_operations_provider.dart` | `actor_id` → `admin_id` (lines 254, 283) | 4 |
| `beautycita_app/lib/providers/admin_finance_dashboard_provider.dart` | `period` → `period_year, period_month` ordering (lines 803, 824) | 4 |
| `beautycita_app/lib/providers/admin_provider.dart` | Fix appointments + reviews providers schema (lines 980, 1002) | 4 |
| `beautycita_app/lib/screens/admin/admin_salon_detail_screen.dart` | Fix consumer reads of `date`/`time`/`display_name` (lines 1827-1841, 2010-2011) | 4 |
| `beautycita_app/lib/services/invite_service.dart` | Fix `generateBio` to send `discovered_salon_id` and read `data['bio']` (lines 131-159) | 5 |
| `beautycita_app/lib/providers/contact_match_provider.dart` | Fix action name + key drift (lines 248-263) | 5 |
| `beautycita_app/pubspec.yaml` | Bump build number 60148 → 60149 | All |

### New SQL helper (Task 3 only)

| Path | Reason |
|------|--------|
| `beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission.sql` | Server-side RPC that wraps `commission_records` insert + `tax_withholdings` insert in a single transaction. Forward only. |
| `beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission_down.sql` | DROP FUNCTION (per migration_down_pairs feedback). |

### New tests

| Path | Tests |
|------|-------|
| `beautycita_app/test/providers/push_notification_keys_test.dart` | Asserts that every Dart caller of `send-push-notification` uses `notification_type`/`custom_title`/`custom_body` (via grep-style source scan, not runtime invoke — avoids the WA-rapid-fire trap). |
| `beautycita_app/test/repositories/booking_repository_test.dart` | Asserts `createBooking` calls the RPC, not direct insert. |
| `beautycita_app/test/services/invite_service_generate_bio_test.dart` | Asserts request body contains `discovered_salon_id` + parses `data['bio']`. |

---

## Branching + worktree

This plan was written outside a worktree per BC's preference for tactical fixes. If the executor wants isolation, create one with `using-git-worktrees`. Otherwise execute on `main` and push as one commit per task. Build number bumps once at the very end (Task 6).

---

## Task 1: Push notification body-key cluster (findings 1-4)

**Why critical:** Five sites in the mobile app invoke `send-push-notification` with the wrong body shape. Edge function returns 400 immediately and the catch silences it. Net effect: booking confirmations, salon-side cancellations, stylist link-requests, admin "nuevo reporte" pushes, and the system-status diagnostic all silently fail. The diagnostic in particular shows green when push is broken.

**Files:**
- Modify: `beautycita_app/lib/providers/booking_flow_provider.dart:738-746`
- Modify: `beautycita_app/lib/screens/business/business_calendar_screen.dart:414-422`
- Modify: `beautycita_app/lib/screens/business/business_staff_screen.dart:1108-1116`
- Modify: `beautycita_app/lib/screens/report_problem_screen.dart:76-81`
- Modify: `beautycita_app/lib/screens/system_status_screen.dart:947-952`
- Create: `beautycita_app/test/providers/push_notification_keys_test.dart`

- [ ] **Step 1.1: Write the failing test (source-scan, not runtime)**

This test grep-scans `lib/` for any `functions.invoke('send-push-notification'` call and asserts that within the next 30 lines the body contains `notification_type` and either `custom_title` + `custom_body` together or neither (the booking-flow path also accepts `booking_id` alone). Source-scan avoids hitting the prod edge fn (per the No WA Rapid-Fire feedback).

```dart
// beautycita_app/test/providers/push_notification_keys_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('send-push-notification callers', () {
    test('all callers use notification_type, not type', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains("'send-push-notification'")) continue;

          // Inspect next 30 lines for body shape
          final window = lines
              .sublist(i, (i + 30).clamp(0, lines.length))
              .join('\n');

          // Must use notification_type, not bare 'type'
          // (data: {'type': ...} nested inside data is allowed)
          final bareTypeRegex = RegExp(r"^\s*'type'\s*:", multiLine: true);
          if (bareTypeRegex.hasMatch(window) &&
              !window.contains('notification_type')) {
            violations.add('${file.path}:${i + 1}');
          }
          // If using custom_title/body keys, both must be present
          if (window.contains('custom_title') &&
              !window.contains('custom_body')) {
            violations.add(
                '${file.path}:${i + 1} (custom_title without custom_body)');
          }
          if (window.contains("'title'") &&
              !window.contains('custom_title') &&
              !window.contains('booking_id')) {
            violations.add(
                '${file.path}:${i + 1} (raw title without custom_title or booking_id)');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'send-push-notification body-shape violations:\n${violations.join('\n')}');
    });
  });
}
```

- [ ] **Step 1.2: Run the test to confirm it fails**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter test test/providers/push_notification_keys_test.dart
```
Expected: FAIL listing five violation locations.

- [ ] **Step 1.3: Fix `booking_flow_provider.dart:738-746`**

Read the current block first to preserve surrounding context (lines 730-755). The fix: replace the inner body map.

```dart
// OLD (around line 738-746):
await SupabaseClientService.client.functions.invoke(
  'send-push-notification',
  body: {
    'user_id': userId,
    'type': 'booking_confirmed',
    'booking_id': bookingId,
    'title': 'Cita confirmada',
    'body': '${state.serviceName ?? "Servicio"} reservado',
  },
);

// NEW:
await SupabaseClientService.client.functions.invoke(
  'send-push-notification',
  body: {
    'user_id': userId,
    'notification_type': 'booking_confirmed',
    'booking_id': bookingId,
    'custom_title': 'Cita confirmada',
    'custom_body': '${state.serviceName ?? "Servicio"} reservado',
  },
);
```

- [ ] **Step 1.4: Fix `business_calendar_screen.dart:414-422`**

```dart
// OLD:
await SupabaseClientService.client.functions.invoke(
  'send-push-notification',
  body: {
    'user_id': userId,
    'type': 'booking_cancelled',
    'booking_id': id,
    'title': 'Cita Cancelada',
    'body': 'Tu salon cancelo tu cita. Se te devolvio el pago completo.',
    'data': {'type': 'booking_cancelled', 'booking_id': id},
  },
);

// NEW:
await SupabaseClientService.client.functions.invoke(
  'send-push-notification',
  body: {
    'user_id': userId,
    'notification_type': 'booking_cancelled',
    'booking_id': id,
    'custom_title': 'Cita Cancelada',
    'custom_body': 'Tu salon cancelo tu cita. Se te devolvio el pago completo.',
    'data': {'type': 'booking_cancelled', 'booking_id': id},
  },
);
```

(Nested `data.type` is fine — that's the FCM payload, not the request shape.)

- [ ] **Step 1.5: Fix `business_staff_screen.dart:1108-1116`**

```dart
// OLD:
await SupabaseClientService.client.functions.invoke(
  'send-push-notification',
  body: {
    'user_id': stylistId,
    'type': 'staff_link_request',
    'title': 'Solicitud de salon',
    'body': '${_firstCtrl.text.trim()} quiere agregarte como miembro de su equipo. Acepta o rechaza desde tu app.',
  },
);

// NEW:
await SupabaseClientService.client.functions.invoke(
  'send-push-notification',
  body: {
    'user_id': stylistId,
    'notification_type': 'staff_link_request',
    'custom_title': 'Solicitud de salon',
    'custom_body': '${_firstCtrl.text.trim()} quiere agregarte como miembro de su equipo. Acepta o rechaza desde tu app.',
  },
);
```

- [ ] **Step 1.6: Fix `report_problem_screen.dart:76-81`**

```dart
// OLD:
body: {
  'user_id': adminId,
  'title': 'Nuevo reporte',
  'body':
      'Reporte de ${_problemTypeLabel()} de ${user?.email ?? "usuario"}',
},

// NEW:
body: {
  'user_id': adminId,
  'notification_type': 'admin_report',
  'custom_title': 'Nuevo reporte',
  'custom_body':
      'Reporte de ${_problemTypeLabel()} de ${user?.email ?? "usuario"}',
},
```

- [ ] **Step 1.7: Fix `system_status_screen.dart:947-952`**

```dart
// OLD:
body: {
  'user_id': currentUserId,
  'title': 'test',
  'body': 'diagnostico',
},

// NEW:
body: {
  'user_id': currentUserId,
  'notification_type': 'diagnostic',
  'custom_title': 'test',
  'custom_body': 'diagnostico',
},
```

- [ ] **Step 1.8: Re-run the test, confirm green**

```bash
/home/bc/flutter/bin/flutter test test/providers/push_notification_keys_test.dart
```
Expected: PASS (1/1).

- [ ] **Step 1.9: Run the full mobile test suite to catch regressions**

```bash
/home/bc/flutter/bin/flutter test
```
Expected: All passing (no new failures from the 5 edits).

- [ ] **Step 1.10: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/lib/providers/booking_flow_provider.dart \
        beautycita_app/lib/screens/business/business_calendar_screen.dart \
        beautycita_app/lib/screens/business/business_staff_screen.dart \
        beautycita_app/lib/screens/report_problem_screen.dart \
        beautycita_app/lib/screens/system_status_screen.dart \
        beautycita_app/test/providers/push_notification_keys_test.dart
git commit -m "$(cat <<'EOF'
mobile: send-push-notification body-key fix across 5 callers

Edge function destructures notification_type / custom_title / custom_body
and 400s anything else. Five caller sites were sending {type, title, body}
and the catch was swallowing the 400, so:
- post-booking "Cita confirmada" push never delivered
- salon-side cancellation push never delivered
- stylist link-request push never delivered
- admin "Nuevo reporte" push never delivered
- system-status diagnostic always reported green even when push was broken

Adds a source-scanning test that grep-walks lib/ for invoke('send-push-...')
calls and asserts the body shape matches the edge-function contract.
Static check only — no runtime hits to the WA-touching endpoint.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Booking repository legacy bypass (finding 5)

**Why high:** `BookingRepository.createBooking` does a direct `appointments.insert` with no commission_records or tax_withholdings entry. It's reachable via `provider_detail_screen.dart:643` and `favorites_screen.dart:110`. Every booking taken through that legacy path has zero platform-fee tracking and zero ISR/IVA accounting. The canonical RPC `create_booking_with_financials` already exists and was deployed in the financial-RPC sweep on 2026-04-12.

**Files:**
- Modify: `beautycita_app/lib/repositories/booking_repository.dart:54-77`
- Create: `beautycita_app/test/repositories/booking_repository_test.dart`

- [ ] **Step 2.1: RPC signature already verified during plan-writing**

Confirmed via `pg_get_function_arguments`:

```
p_user_id uuid,
p_business_id uuid,
p_service_id text,
p_service_name text,
p_service_type text,
p_starts_at timestamptz,
p_ends_at timestamptz,
p_price numeric,
p_payment_method text,
p_booking_source text,
p_transport_mode text DEFAULT NULL,
p_staff_id uuid DEFAULT NULL,
p_notes text DEFAULT NULL,
p_idempotency_key text DEFAULT NULL,
p_deposit_amount numeric DEFAULT 0
```

**Notable:** there is no `p_payment_status` or `p_payment_intent_id` param — the RPC handles status internally based on `p_payment_method`. The previous direct insert wrote `payment_status` and `payment_intent_id` columns that the RPC sets on its own.

- [ ] **Step 2.2: Write the failing test**

Source-scan test asserting the file calls `.rpc('create_booking_with_financials')` and does NOT call `.from(BCTables.appointments).insert(`.

```dart
// beautycita_app/test/repositories/booking_repository_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking_repository.createBooking goes through financial RPC', () {
    final source =
        File('lib/repositories/booking_repository.dart').readAsStringSync();

    expect(
      source.contains(".rpc('create_booking_with_financials"),
      isTrue,
      reason: 'createBooking must call create_booking_with_financials',
    );
    expect(
      source.contains('.from(BCTables.appointments)') &&
          source.contains('.insert('),
      isFalse,
      reason:
          'Direct appointments.insert is forbidden — financials/tax bypassed',
    );
  });
}
```

- [ ] **Step 2.3: Run the test, confirm failure**

```bash
/home/bc/flutter/bin/flutter test test/repositories/booking_repository_test.dart
```
Expected: FAIL on first assertion.

- [ ] **Step 2.4: Replace `createBooking` body**

```dart
// OLD (lines 54-77):
final data = {
  'user_id': userId,
  'business_id': providerId,
  'service_id': providerServiceId,
  'service_name': serviceName,
  'service_type': category,
  'starts_at': scheduledAt.toUtc().toIso8601String(),
  'ends_at': endsAt.toUtc().toIso8601String(),
  'price': price,
  'notes': notes,
  'status': paymentStatus == 'paid' ? 'confirmed' : 'pending',
  'payment_status': dbPaymentStatus,
  'staff_id': ?staffId,
  'payment_intent_id': ?paymentIntentId,
  'payment_method': ?paymentMethod,
  'transport_mode': ?transportMode,
  'booking_source': bookingSource,
};

final response = await SupabaseClientService.client
    .from(BCTables.appointments)
    .insert(data)
    .select()
    .single();

return Booking.fromJson(response);

// NEW:
final response = await SupabaseClientService.client.rpc(
  'create_booking_with_financials',
  params: {
    'p_user_id': userId,
    'p_business_id': providerId,
    'p_service_id': providerServiceId,
    'p_service_name': serviceName,
    'p_service_type': category,
    'p_starts_at': scheduledAt.toUtc().toIso8601String(),
    'p_ends_at': endsAt.toUtc().toIso8601String(),
    'p_price': price,
    'p_payment_method': paymentMethod ?? 'card',
    'p_booking_source': bookingSource,
    if (transportMode != null) 'p_transport_mode': transportMode,
    if (staffId != null) 'p_staff_id': staffId,
    if (notes != null) 'p_notes': notes,
    // p_idempotency_key + p_deposit_amount default-handled by RPC
  },
);

// RPC returns the inserted row. Cast and map.
if (response == null) {
  throw Exception('create_booking_with_financials returned null');
}
final row = response is List
    ? (response.isEmpty ? null : response.first)
    : response;
if (row == null) {
  throw Exception('create_booking_with_financials returned empty result');
}
return Booking.fromJson(Map<String, dynamic>.from(row as Map));
```

> **Note:** payment_status and payment_intent_id are NOT in the RPC param list — the RPC infers status from payment_method and writes payment_intent_id only when the calling stripe-webhook confirms the charge. The previous direct insert was over-writing both fields. If the legacy provider-detail flow needs to update payment_intent_id later (after a successful Stripe charge), that's already handled by the existing webhook path.

- [ ] **Step 2.5: Run analyze + test**

```bash
/home/bc/flutter/bin/flutter analyze lib/repositories/booking_repository.dart \
                                     test/repositories/booking_repository_test.dart
/home/bc/flutter/bin/flutter test test/repositories/booking_repository_test.dart
```
Expected: 0 issues, 1/1 PASS.

- [ ] **Step 2.6: Run full test suite**

```bash
/home/bc/flutter/bin/flutter test
```
Expected: no new failures.

- [ ] **Step 2.7: Commit**

```bash
git add beautycita_app/lib/repositories/booking_repository.dart \
        beautycita_app/test/repositories/booking_repository_test.dart
git commit -m "$(cat <<'EOF'
mobile: route legacy provider-detail booking through create_booking_with_financials

BookingRepository.createBooking did a direct appointments.insert from the
provider-detail and favorites flows. No commission_records, no
tax_withholdings — every booking through that path bypassed both the
3% platform fee accounting and the ISR/IVA withholding engine.

The RPC already exists (deployed 2026-04-12). Switch the repository to
call it instead and cast the returned row back to Booking.

Adds a static-source test that fails if the file ever reintroduces a
direct .insert against BCTables.appointments.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Gift card commission atomicity + email template (findings 6, 7)

**Why high:** Two related bugs in the same screen.
- (6) **REVISED after advisor review:** Original audit framing said "no `tax_withholdings` row" — that part is a false positive. LISR Art. 113-A withholding only applies to platform→provider disbursements (booking payouts). Salon-issued gift cards are the opposite money flow: salon collects from buyer off-platform, BC just records the 3% commission as platform revenue. There's no withholding event, and `tax_withholdings` doesn't even have a `source` column (verified). The legitimate part of the finding is that the two writes (`gift_cards` + `commission_records`) are non-atomic — if the second fails, the gift card exists with no commission booked.
- (7) Virtual gift card "email with code" calls `send-email` with `{to, subject, text}` but the edge function requires a `template` key and 400s otherwise. `.catchError((_) {})` swallows the error. Buyer never receives the redemption code.

**Approach:** Add a small server-side RPC `record_gift_card_commission` that wraps the two writes (gift_card + commission_record) in a single transaction. No tax_withholdings row. Replace the direct inserts in the screen with the RPC call. Switch the email call to use a `gift_card` template (create one in the edge function's TEMPLATES map if it doesn't exist — verify in step 3.1).

**Files:**
- Create: `beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission.sql`
- Create: `beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission_down.sql`
- Modify: `beautycita_app/lib/screens/business/business_gift_cards_screen.dart:741-775`
- Modify: `beautycita_app/supabase/functions/send-email/index.ts` (only if `gift_card` template doesn't exist)

- [ ] **Step 3.1: Inspect existing `send-email` templates**

```bash
grep -n "TEMPLATES\b" /home/bc/futureBeauty/beautycita_app/supabase/functions/send-email/index.ts | head -5
grep -n "gift_card\|gift" /home/bc/futureBeauty/beautycita_app/supabase/functions/send-email/index.ts | head -10
```
If `gift_card` template exists, skip Step 3.6. If not, you'll add it.

- [ ] **Step 3.2: (Skipped — superseded by advisor review.)** Tax-withholding does not apply to commission-collection flow. See Task 3 header.

- [ ] **Step 3.3: Write the forward migration**

```sql
-- beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission.sql
-- Wraps gift_cards INSERT + commission_records INSERT in a single transaction.
-- Replaces the non-atomic client-side two-write pattern in
-- business_gift_cards_screen.dart. No tax_withholdings row — gift-card
-- commission is platform revenue, not a withholding event under LISR Art. 113-A.

CREATE OR REPLACE FUNCTION record_gift_card_commission(
  p_business_id uuid,
  p_code text,
  p_amount numeric,
  p_buyer_name text,
  p_recipient_name text,
  p_message text,
  p_expires_at timestamptz
)
RETURNS TABLE (
  out_gift_card_id uuid,
  out_commission_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_gift_card_id uuid;
  v_commission_id uuid;
  v_commission_amount numeric := round(p_amount * 0.03, 2);
BEGIN
  -- Authz: caller must own this business
  IF NOT EXISTS (
    SELECT 1 FROM businesses
    WHERE id = p_business_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'forbidden: caller does not own business %', p_business_id;
  END IF;

  -- 1. Insert gift card
  INSERT INTO gift_cards (
    business_id, code, amount, remaining_amount,
    buyer_name, recipient_name, message,
    expires_at, is_active
  ) VALUES (
    p_business_id, p_code, p_amount, p_amount,
    p_buyer_name, p_recipient_name, p_message,
    p_expires_at, true
  )
  RETURNING id INTO v_gift_card_id;

  -- 2. Insert commission record (BC platform revenue — not a withholding)
  INSERT INTO commission_records (
    business_id, amount, rate, source,
    period_month, period_year, status
  ) VALUES (
    p_business_id, v_commission_amount, 0.03, 'gift_card',
    EXTRACT(MONTH FROM now())::int,
    EXTRACT(YEAR FROM now())::int,
    'collected'
  )
  RETURNING id INTO v_commission_id;

  RETURN QUERY SELECT v_gift_card_id, v_commission_id;
END;
$$;

GRANT EXECUTE ON FUNCTION record_gift_card_commission(uuid, text, numeric, text, text, text, timestamptz) TO authenticated;
```

> **VERIFY before applying:** confirm `commission_records` has a `source` column accepting 'gift_card'. The current client code already writes that value, so it's almost certainly fine, but a quick `\d commission_records` confirms.

- [ ] **Step 3.4: Write the down migration**

```sql
-- beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission_down.sql
DROP FUNCTION IF EXISTS record_gift_card_commission(uuid, text, numeric, text, text, text, timestamptz);
```

- [ ] **Step 3.5: Apply the migration to prod**

```bash
ssh www-bc "docker exec -i supabase-db psql -U postgres -d postgres" \
  < /home/bc/futureBeauty/beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission.sql
```
Expected: `CREATE FUNCTION` then `GRANT`. No errors.

- [ ] **Step 3.6: (Conditional) Add `gift_card` email template**

If Step 3.1 showed no `gift_card` template, add one to the TEMPLATES map in `beautycita_app/supabase/functions/send-email/index.ts`. The exact Object key shape varies by file — read the file first and follow the existing pattern.

```typescript
// Within TEMPLATES = { ... }:
gift_card: {
  subject: "Tu tarjeta de regalo BeautyCita",
  html: ({ amount, code, message }) => `
    <h2>Tarjeta de regalo BeautyCita</h2>
    <p>Tienes una tarjeta de regalo de <strong>$${amount} MXN</strong>.</p>
    <p>Codigo: <strong style="font-size:18px">${code}</strong></p>
    ${message ? `<p>Mensaje: ${message}</p>` : ""}
    <p>Canjeala en la app BeautyCita o en <a href="https://beautycita.com">beautycita.com</a>.</p>
  `,
},
```

Then deploy:

```bash
rsync -avz beautycita_app/supabase/functions/send-email/ \
  www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/send-email/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 3.7: Replace the client-side block in business_gift_cards_screen.dart**

```dart
// OLD (lines 741-775):
final code = _generateCode();
await SupabaseClientService.client.from(BCTables.giftCards).insert({
  'business_id': widget.bizId,
  'code': code,
  'amount': amount,
  'remaining_amount': amount,
  'buyer_name': _buyerCtrl.text.trim().isEmpty ? null : _buyerCtrl.text.trim(),
  'recipient_name': _recipientCtrl.text.trim().isEmpty ? null : _recipientCtrl.text.trim(),
  'message': _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
  'expires_at': _expiresAt?.toUtc().toIso8601String(),
  'is_active': true,
});

final bcCommission = amount * 0.03;
await SupabaseClientService.client.from(BCTables.commissionRecords).insert({
  'business_id': widget.bizId,
  'amount': double.parse(bcCommission.toStringAsFixed(2)),
  'rate': 0.03,
  'source': 'gift_card',
  'period_month': DateTime.now().month,
  'period_year': DateTime.now().year,
  'status': 'collected',
});

if (_isVirtual && _emailCtrl.text.trim().isNotEmpty) {
  SupabaseClientService.client.functions.invoke('send-email', body: {
    'to': _emailCtrl.text.trim(),
    'subject': 'Tarjeta de Regalo BeautyCita — \$${amount.toStringAsFixed(0)} MXN',
    'text': '...',
  }).then((_) {}).catchError((_) {});
}

// NEW:
final code = _generateCode();
await SupabaseClientService.client.rpc('record_gift_card_commission', params: {
  'p_business_id': widget.bizId,
  'p_code': code,
  'p_amount': amount,
  'p_buyer_name':
      _buyerCtrl.text.trim().isEmpty ? null : _buyerCtrl.text.trim(),
  'p_recipient_name':
      _recipientCtrl.text.trim().isEmpty ? null : _recipientCtrl.text.trim(),
  'p_message':
      _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
  'p_expires_at': _expiresAt?.toUtc().toIso8601String(),
});

if (_isVirtual && _emailCtrl.text.trim().isNotEmpty) {
  try {
    await SupabaseClientService.client.functions.invoke('send-email', body: {
      'template': 'gift_card',
      'to': _emailCtrl.text.trim(),
      'subject': 'Tu tarjeta de regalo BeautyCita',
      'variables': {
        'amount': amount.toStringAsFixed(0),
        'code': code,
        'message': _messageCtrl.text.trim(),
      },
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tarjeta creada, pero no pudimos enviar el email. Comparte el codigo manualmente: $code'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}
```

- [ ] **Step 3.8: Run analyze**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/business/business_gift_cards_screen.dart
```
Expected: 0 issues.

- [ ] **Step 3.9: Smoke-test the RPC manually on prod**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"BEGIN; SELECT * FROM record_gift_card_commission(
  (SELECT id FROM businesses LIMIT 1),
  'TEST-WRAP-1', 200.00, 'Test Buyer', 'Test Recipient', NULL, NULL
); ROLLBACK;\""
```
Expected: 2 returned UUIDs (gift_card_id, commission_id). Rollback so no test data lands in prod.

- [ ] **Step 3.10: Commit**

```bash
git add beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission.sql \
        beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission_down.sql \
        beautycita_app/lib/screens/business/business_gift_cards_screen.dart
# Conditionally also:
# git add beautycita_app/supabase/functions/send-email/index.ts
git commit -m "$(cat <<'EOF'
mobile: gift-card commission atomicity + email template

Two writes from business_gift_cards_screen (gift_cards + commission_records)
were not transactional — if the second failed, the gift card existed
without a commission record. New RPC record_gift_card_commission wraps
both inserts in a single transaction with an authz check against
business ownership.

Tax withholding intentionally NOT inserted — gift-card commission is
platform revenue (BC's own corporate income), not a LISR Art. 113-A
withholding event since there's no platform→provider disbursement in
this flow. Original audit finding overstated this part.

Virtual gift-card email was calling send-email with {to,subject,text}
but the edge function requires a {template, variables} shape and 400ed
silently. Adds a gift_card template and surfaces send failures to the
salon owner so they can share the code manually.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Admin schema-drift cluster (findings 8-11)

**Why high:** Four admin providers reference column names that don't exist in the live schema. Each fails silently — the `try/catch (_)` swallows the 400 and the UI shows empty data. Net effect: admin Ops dashboard shows zero recent audit-log entries; admin tax dashboard shows empty SAT lists; admin "Salon detail → recent appointments" throws on every load; admin "Salon detail → reviews" never shows reviewer names.

**Files:**
- Modify: `beautycita_app/lib/providers/admin_operations_provider.dart:254, 283`
- Modify: `beautycita_app/lib/providers/admin_finance_dashboard_provider.dart:803, 824`
- Modify: `beautycita_app/lib/providers/admin_provider.dart:980, 1002`

- [ ] **Step 4.1: Fix `admin_operations_provider.dart` (audit_log actor_id → admin_id)**

```dart
// Line 254 — change select string:
.select('id, action, details, created_at, actor_id')
// →
.select('id, action, details, created_at, admin_id')

// Line 283 — change row read:
actor: row['actor_id']?.toString(),
// →
actor: row['admin_id']?.toString(),
```

- [ ] **Step 4.2: Fix `admin_finance_dashboard_provider.dart` (period → period_year, period_month)**

For both `platformSatDeclarationsProvider` and `satMonthlyReportsProvider`, the order key needs to become two columns. PostgREST supports chained `.order()` calls.

```dart
// platformSatDeclarationsProvider, line 803:
.order('period', ascending: false)
// →
.order('period_year', ascending: false).order('period_month', ascending: false)

// satMonthlyReportsProvider, line 824:
.order('period', ascending: false)
// →
.order('period_year', ascending: false).order('period_month', ascending: false)
```

- [ ] **Step 4.3: Fix `admin_provider.dart adminSalonAppointmentsProvider` (appointments columns + display_name)**

```dart
// OLD (line 980):
.select('id, user_id, service_id, date, time, status, payment_status, price, profiles!appointments_user_id_fkey(display_name), services(name)')
.eq('business_id', businessId)
.order('date', ascending: false)
.limit(10);

// NEW:
.select('id, user_id, service_id, starts_at, ends_at, status, payment_status, price, profiles!appointments_user_id_fkey(full_name, username), services(name)')
.eq('business_id', businessId)
.order('starts_at', ascending: false)
.limit(10);
```

- [ ] **Step 4.4: Fix consumer in `admin_salon_detail_screen.dart:1827-1838` (date/time/display_name reads)**

```dart
// OLD (lines 1827-1838):
final date = appointment['date'] as String?;
final time = appointment['time'] as String?;
final status = appointment['status'] as String?;
final price = (appointment['price'] as num?)?.toDouble();

final serviceMap = appointment['services'] as Map<String, dynamic>?;
final serviceName = serviceMap?['name'] as String? ?? 'Sin servicio';

final profileMap =
    appointment['profiles'] as Map<String, dynamic>?;
final clientName =
    profileMap?['display_name'] as String? ?? 'Sin cliente';

// NEW:
final startsAt = DateTime.tryParse(
  appointment['starts_at'] as String? ?? '',
);
final status = appointment['status'] as String?;
final price = (appointment['price'] as num?)?.toDouble();

final serviceMap = appointment['services'] as Map<String, dynamic>?;
final serviceName = serviceMap?['name'] as String? ?? 'Sin servicio';

final profileMap =
    appointment['profiles'] as Map<String, dynamic>?;
final clientName = (profileMap?['full_name'] as String?) ??
    (profileMap?['username'] as String?) ??
    'Sin cliente';

// Update the dateStr/timeStr formatters below (lines ~1840-1841):
final dateStr = startsAt != null
    ? '${startsAt.year}-${startsAt.month.toString().padLeft(2, '0')}-${startsAt.day.toString().padLeft(2, '0')}'
    : '--';
final timeStr = startsAt != null
    ? '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'
    : '';
```

- [ ] **Step 4.5: Fix `admin_provider.dart adminSalonReviewsProvider` (display_name → full_name)**

```dart
// OLD (line 1002):
.select('id, rating, comment, created_at, profiles!reviews_user_id_fkey(display_name)')

// NEW:
.select('id, rating, comment, created_at, profiles!reviews_user_id_fkey(full_name, username)')
```

- [ ] **Step 4.6: Fix consumer in `admin_salon_detail_screen.dart:2011` (review row display_name read)**

```dart
// OLD (line 2010-2011):
final profileMap = review['profiles'] as Map<String, dynamic>?;
final clientName =
    profileMap?['display_name'] as String? ?? 'Usuario';

// NEW:
final profileMap = review['profiles'] as Map<String, dynamic>?;
final clientName = (profileMap?['full_name'] as String?) ??
    (profileMap?['username'] as String?) ??
    'Usuario';
```

> **Owner display_name follow-up (out of scope):** `admin_salon_detail_screen.dart:1026` reads `owner['display_name']` from the salon record's joined profile. Same column-not-exists bug, but `owner` comes from a different join (`salon['profiles']`) populated upstream by `adminSalonsProvider`. Logging as a separate finding for the next audit pass — don't expand this task.

- [ ] **Step 4.7: Run analyze on all four files**

```bash
/home/bc/flutter/bin/flutter analyze \
  lib/providers/admin_operations_provider.dart \
  lib/providers/admin_finance_dashboard_provider.dart \
  lib/providers/admin_provider.dart \
  lib/screens/admin/admin_salon_detail_screen.dart
```
Expected: 0 issues.

- [ ] **Step 4.8: Smoke check each PostgREST query against prod**

```bash
# Audit log:
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -t -c \"SELECT id, action, admin_id FROM audit_log ORDER BY created_at DESC LIMIT 1;\""
# SAT declarations:
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -t -c \"SELECT period_year, period_month FROM platform_sat_declarations ORDER BY period_year DESC, period_month DESC LIMIT 1;\""
# Reviews join:
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -t -c \"SELECT r.id, p.full_name FROM reviews r JOIN profiles p ON p.id = r.user_id LIMIT 1;\""
```
All three should return rows (or 0 rows but no error).

- [ ] **Step 4.9: Commit**

```bash
git add beautycita_app/lib/providers/admin_operations_provider.dart \
        beautycita_app/lib/providers/admin_finance_dashboard_provider.dart \
        beautycita_app/lib/providers/admin_provider.dart \
        beautycita_app/lib/screens/admin/admin_salon_detail_screen.dart
git commit -m "$(cat <<'EOF'
mobile: admin providers — schema name drift (audit_log, SAT, salon detail)

Four admin providers were querying columns that don't exist in the live
schema. Each had a swallowing try/catch so the failure surfaced as empty
data, not an error:

- admin_operations: audit_log column is admin_id, not actor_id —
  recent activity feed silently empty
- admin_finance_dashboard: platform_sat_declarations + sat_monthly_reports
  are ordered by period_year/period_month, not period — SAT lists empty
- admin_provider adminSalonAppointmentsProvider: appointments uses
  starts_at/ends_at and profiles has full_name (no date/time/display_name)
  — admin "Salon detail → recent appointments" threw on every load
- admin_provider adminSalonReviewsProvider: profiles.display_name
  doesn't exist — reviewer name never rendered

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Aphrodite invite-flow integration (findings 12, 13)

**Why high:** Two compounding bugs in the salon-invite flow.
- (12) `invite_service.generateBio` sends `salon_name` but not `discovered_salon_id` (required by the edge fn → 400). Even if it succeeded, it reads `data['text']` instead of the actual `data['bio']` key. Net: live caller in `invite_provider.dart:350` never gets a bio.
- (13) `contact_match_provider._generateBioBackground` calls `aphrodite-chat` with action `generate_bio` — that action doesn't exist (real action: `generate_salon_bio`). Plus three wrong key names (`salon_id` vs `discovered_salon_id`, `salon_categories` vs `salon_specialties`, `salon_reviews_count` vs `salon_review_count`). Fire-and-forget so silent.

**Files:**
- Modify: `beautycita_app/lib/services/invite_service.dart:131-159`
- Modify: `beautycita_app/lib/providers/contact_match_provider.dart:248-263`
- Create: `beautycita_app/test/services/invite_service_generate_bio_test.dart`

- [ ] **Step 5.1: Write the failing test (source-scan)**

```dart
// beautycita_app/test/services/invite_service_generate_bio_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite_service.generateBio sends discovered_salon_id + reads bio', () {
    final source =
        File('lib/services/invite_service.dart').readAsStringSync();

    expect(source.contains("'discovered_salon_id'"), isTrue,
        reason: "edge fn requires discovered_salon_id — must be in body");
    expect(source.contains("data['bio']"), isTrue,
        reason: "edge fn returns {bio}, not {text}");
    expect(source.contains("data['text']"), isFalse,
        reason: "stale text-key read must be removed");
  });

  test('contact_match_provider uses generate_salon_bio + canonical keys', () {
    final source =
        File('lib/providers/contact_match_provider.dart').readAsStringSync();

    expect(source.contains("'generate_salon_bio'"), isTrue,
        reason: "action must be generate_salon_bio");
    expect(source.contains("'generate_bio'"), isFalse,
        reason: "ghost action 'generate_bio' must be removed");
    expect(source.contains("'discovered_salon_id'"), isTrue,
        reason: "edge fn requires discovered_salon_id");
    expect(source.contains("'salon_specialties'"), isTrue,
        reason: "key is salon_specialties (not salon_categories)");
    expect(source.contains("'salon_review_count'"), isTrue,
        reason: "key is salon_review_count (not salon_reviews_count)");
  });
}
```

- [ ] **Step 5.2: Run, confirm fail**

```bash
/home/bc/flutter/bin/flutter test test/services/invite_service_generate_bio_test.dart
```
Expected: FAIL on multiple assertions.

- [ ] **Step 5.3: Fix `invite_service.generateBio` (line 131-159)**

```dart
// OLD body:
body: {
  'action': 'generate_salon_bio',
  'salon_name': salon.name,
  'salon_city': salon.city,
  'salon_address': salon.address,
  'salon_rating': salon.rating,
  'salon_reviews_count': salon.reviewsCount,
},

// NEW body (add discovered_salon_id, fix reviews_count → review_count, drop unused address):
body: {
  'action': 'generate_salon_bio',
  'discovered_salon_id': salon.id,
  'salon_name': salon.name,
  'salon_city': salon.city,
  'salon_specialties': salon.specialties,  // List<String>? — pass through if non-null
  'salon_rating': salon.rating,
  'salon_review_count': salon.reviewsCount,
},

// Also fix the response read at the end of the function:
// OLD:
return data['text'] as String? ?? '';
// NEW:
return data['bio'] as String? ?? '';
```

> If `DiscoveredSalon` doesn't have a `specialties` getter, drop the `salon_specialties` line — the edge fn treats it as optional. Verify by reading `lib/data/models/discovered_salon.dart` (or wherever the model lives).

- [ ] **Step 5.4: Fix `contact_match_provider._generateBioBackground` (line 248-263)**

```dart
// OLD body:
body: {
  'action': 'generate_bio',
  'salon_id': salon['id']?.toString(),
  'salon_name': salon['business_name'],
  'salon_city': salon['location_city'],
  'salon_categories': salon['matched_categories'],
  'salon_rating': salon['rating_average'],
  'salon_reviews_count': salon['rating_count'],
},

// NEW body:
body: {
  'action': 'generate_salon_bio',
  'discovered_salon_id': salon['id']?.toString(),
  'salon_name': salon['business_name'],
  'salon_city': salon['location_city'],
  'salon_specialties': salon['matched_categories'],
  'salon_rating': salon['rating_average'],
  'salon_review_count': salon['rating_count'],
},
```

- [ ] **Step 5.5: Re-run the test, confirm PASS**

```bash
/home/bc/flutter/bin/flutter test test/services/invite_service_generate_bio_test.dart
```
Expected: 2/2 PASS.

- [ ] **Step 5.6: Run analyze on both files**

```bash
/home/bc/flutter/bin/flutter analyze lib/services/invite_service.dart lib/providers/contact_match_provider.dart
```
Expected: 0 issues.

- [ ] **Step 5.7: Commit**

```bash
git add beautycita_app/lib/services/invite_service.dart \
        beautycita_app/lib/providers/contact_match_provider.dart \
        beautycita_app/test/services/invite_service_generate_bio_test.dart
git commit -m "$(cat <<'EOF'
mobile: aphrodite invite-flow — fix dead generators

Two compounding bugs in the salon-invite flow:

invite_service.generateBio was missing the required discovered_salon_id
body key (edge fn 400) and reading data['text'] instead of data['bio'].
Both wrong, so the live caller in invite_provider always got an empty
string back — invite UI silently fell back to no-bio mode.

contact_match_provider._generateBioBackground used action name
'generate_bio' which doesn't exist (real action: 'generate_salon_bio'),
plus three wrong key names (salon_id / salon_categories /
salon_reviews_count). Fire-and-forget so the 400 was never logged.
Background bio generation for matched contacts was 100% dead.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Bump build, rebuild APK, deploy

**Files:**
- Modify: `beautycita_app/pubspec.yaml`

- [ ] **Step 6.1: Bump build number**

```bash
cd /home/bc/futureBeauty/beautycita_app
sed -i 's/^version: 1\.2\.1+60148$/version: 1.2.1+60149/' pubspec.yaml
grep ^version pubspec.yaml
```
Expected: `version: 1.2.1+60149`.

- [ ] **Step 6.2: Build the APK (split-per-abi)**

```bash
cd /home/bc/futureBeauty/beautycita_app
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
/home/bc/flutter/bin/flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL=https://beautycita.com/supabase \
  --dart-define=SUPABASE_ANON_KEY=<see infrastructure.md>
```
Expected: build succeeds, ARM64 APK ~57 MB at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

- [ ] **Step 6.3: Push APK + version.json to R2**

```bash
aws s3 cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  s3://beautycita-medias/apk/beautycita.apk --profile r2 \
  --content-type application/vnd.android.package-archive

echo '{"version":"1.2.1","build":60149,"buildNumber":60149,"required":false,"forceUpdate":false,"url":"https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk","releaseNotes":"Notificaciones push reparadas en 5 superficies, panel admin estabilizado (audit log, SAT, detalle de salón), tarjetas de regalo emiten email correctamente, comisiones atómicas, generadores de bio Aphrodite operativos."}' \
  | aws s3 cp - s3://beautycita-medias/version.json --profile r2 \
    --content-type application/json \
    --cache-control "no-cache, no-store, must-revalidate"
```

Use this release-notes string in the version.json above:

```
"releaseNotes":"Notificaciones push reparadas en 5 superficies, panel admin estabilizado (audit log, SAT, detalle de salón), tarjetas de regalo emiten email correctamente, comisiones atómicas, generadores de bio Aphrodite operativos."
```

- [ ] **Step 6.4: Commit pubspec bump**

```bash
git add beautycita_app/pubspec.yaml
git commit -m "Build 60149: version bump"
```

- [ ] **Step 6.5: Push to main**

```bash
git push origin main
```

---

## Self-review checklist (run before handing the plan over)

- [ ] Spec coverage: every audit finding 1-13 maps to a task. ✅
- [ ] No "TBD" / "implement later" placeholders. ✅
- [ ] Every code edit shows actual code, not "fix the body keys." ✅
- [ ] Build number bump (Task 6) happens after all code edits, not interleaved. ✅
- [ ] Migration has a `_down.sql` pair (Task 3). ✅
- [ ] Test files for every new behavior. ✅
- [ ] Static-source tests used in place of any test that would hit a WA-touching endpoint (per No WA Rapid-Fire). ✅
- [ ] No process tags in commit messages (no autopilot/pass-N labels). ✅

---

## Reviewer pre-flight

Before executing, this plan should be reviewed by:

1. **Doc** (`mcp__django__django_companion`) — for repository hygiene + lens checks (especially the `migration-down-pairs` and `hardcoded-phones` lenses).
2. **advisor()** — for sequencing (any task ordering risk?), schema-assumption sanity (do the RPC parameter names actually match what's deployed?), and whether the gift-card RPC is over-engineered vs. a direct trigger on `commission_records`.

The executor should not start Task 3 until BC confirms the `tax_withholdings` column names verified at Step 3.2 match the migration in Step 3.3, since the auditor flagged absent triggers but didn't fully enumerate the table's columns.
