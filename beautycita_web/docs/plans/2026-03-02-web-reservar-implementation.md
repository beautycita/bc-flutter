# Web Reservar Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the complete `/reservar` client booking flow for the BeautyCita web app — from category selection through payment confirmation and post-booking transport.

**Architecture:** Single-page progressive flow using internal state (no route changes). Two-column desktop layout (active step 60% | summary sidebar 40%), collapsing to single column + sticky bottom bar on mobile. Six steps: category grid → subcategory/service → follow-up questions → results (curated or discovered) → payment → post-booking transport. Riverpod for state, Stripe.js for web payments.

**Tech Stack:** Flutter Web, Riverpod, GoRouter (existing), Supabase (existing edge functions), Stripe.js (new — dart:js_interop), beautycita_core models/theme.

---

## Task 1: Booking Flow State Provider

**Files:**
- Create: `lib/providers/booking_flow_provider.dart`

**Step 1: Create the booking flow state and provider**

This provider manages the entire progressive flow. No tests — it's a state container.

```dart
// lib/providers/booking_flow_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart';

enum BookingStep {
  category,
  service,
  followUp,
  results,
  payment,
  transport,
  confirmed,
}

class BookingFlowState {
  final BookingStep step;
  final ServiceCategory? selectedCategory;
  final ServiceSubcategory? selectedSubcategory;
  final ServiceItem? selectedService;
  final Map<String, String> followUpAnswers;
  final CurateResponse? curateResponse;
  final ResultCard? selectedResult;
  final List<Map<String, dynamic>> discoveredSalons;
  final bool showingDiscovered;
  final String? transportMode;
  final String? bookingId;
  final bool isLoading;
  final String? error;
  final double? userLat;
  final double? userLng;

  const BookingFlowState({
    this.step = BookingStep.category,
    this.selectedCategory,
    this.selectedSubcategory,
    this.selectedService,
    this.followUpAnswers = const {},
    this.curateResponse,
    this.selectedResult,
    this.discoveredSalons = const [],
    this.showingDiscovered = false,
    this.transportMode,
    this.bookingId,
    this.isLoading = false,
    this.error,
    this.userLat,
    this.userLng,
  });

  BookingFlowState copyWith({
    BookingStep? step,
    ServiceCategory? selectedCategory,
    ServiceSubcategory? selectedSubcategory,
    ServiceItem? selectedService,
    Map<String, String>? followUpAnswers,
    CurateResponse? curateResponse,
    ResultCard? selectedResult,
    List<Map<String, dynamic>>? discoveredSalons,
    bool? showingDiscovered,
    String? transportMode,
    String? bookingId,
    bool? isLoading,
    String? error,
    double? userLat,
    double? userLng,
  }) {
    return BookingFlowState(
      step: step ?? this.step,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedSubcategory: selectedSubcategory ?? this.selectedSubcategory,
      selectedService: selectedService ?? this.selectedService,
      followUpAnswers: followUpAnswers ?? this.followUpAnswers,
      curateResponse: curateResponse ?? this.curateResponse,
      selectedResult: selectedResult ?? this.selectedResult,
      discoveredSalons: discoveredSalons ?? this.discoveredSalons,
      showingDiscovered: showingDiscovered ?? this.showingDiscovered,
      transportMode: transportMode ?? this.transportMode,
      bookingId: bookingId ?? this.bookingId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
    );
  }
}

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  BookingFlowNotifier() : super(const BookingFlowState());

  void selectCategory(ServiceCategory category) {
    state = BookingFlowState(
      step: BookingStep.service,
      selectedCategory: category,
      userLat: state.userLat,
      userLng: state.userLng,
    );
  }

  void selectService(ServiceSubcategory sub, ServiceItem item) {
    state = state.copyWith(
      selectedSubcategory: sub,
      selectedService: item,
      step: BookingStep.followUp,
    );
  }

  void skipFollowUps() {
    state = state.copyWith(step: BookingStep.results, isLoading: true);
  }

  void answerFollowUp(String key, String value) {
    final answers = Map<String, String>.from(state.followUpAnswers);
    answers[key] = value;
    state = state.copyWith(followUpAnswers: answers);
  }

  void submitFollowUps() {
    state = state.copyWith(step: BookingStep.results, isLoading: true);
  }

  void setCurateResponse(CurateResponse response) {
    state = state.copyWith(
      curateResponse: response,
      isLoading: false,
      showingDiscovered: response.results.isEmpty,
    );
  }

  void setDiscoveredSalons(List<Map<String, dynamic>> salons) {
    state = state.copyWith(
      discoveredSalons: salons,
      showingDiscovered: true,
      isLoading: false,
    );
  }

  void showDiscovered() {
    state = state.copyWith(showingDiscovered: true);
  }

  void selectResult(ResultCard result) {
    state = state.copyWith(
      selectedResult: result,
      step: BookingStep.payment,
    );
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  void setBookingConfirmed(String bookingId) {
    state = state.copyWith(
      bookingId: bookingId,
      step: BookingStep.transport,
    );
  }

  void setTransportMode(String mode) {
    state = state.copyWith(
      transportMode: mode,
      step: BookingStep.confirmed,
    );
  }

  void setLocation(double lat, double lng) {
    state = state.copyWith(userLat: lat, userLng: lng);
  }

  void goBack() {
    switch (state.step) {
      case BookingStep.service:
        state = BookingFlowState(
          userLat: state.userLat,
          userLng: state.userLng,
        );
      case BookingStep.followUp:
        state = state.copyWith(
          step: BookingStep.service,
          selectedService: null,
          selectedSubcategory: null,
        );
      case BookingStep.results:
        state = state.copyWith(
          step: BookingStep.followUp,
          curateResponse: null,
          discoveredSalons: const [],
          showingDiscovered: false,
        );
      case BookingStep.payment:
        state = state.copyWith(
          step: BookingStep.results,
          selectedResult: null,
        );
      default:
        break;
    }
  }

  void reset() {
    state = BookingFlowState(
      userLat: state.userLat,
      userLng: state.userLng,
    );
  }
}

final bookingFlowProvider =
    StateNotifierProvider<BookingFlowNotifier, BookingFlowState>(
  (ref) => BookingFlowNotifier(),
);
```

**Step 2: Commit**

```bash
git add lib/providers/booking_flow_provider.dart
git commit -m "feat(web): add booking flow state provider for reservar page"
```

---

## Task 2: Reservar Page Shell + Category Grid (Step 1)

**Files:**
- Create: `lib/pages/client/reservar_page.dart`
- Modify: `lib/config/router.dart:356-360` — replace Placeholder with ReservarPage
- Modify: `lib/shells/client_shell.dart` — add top nav bar with brand + back button

**Step 1: Build the ClientShell with a minimal top bar**

```dart
// lib/shells/client_shell.dart
import 'package:flutter/material.dart';
import 'package:beautycita_core/theme.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BeautyCita',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: child,
    );
  }
}
```

**Step 2: Create the ReservarPage with two-column layout and category grid**

```dart
// lib/pages/client/reservar_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/theme.dart';
import '../../config/breakpoints.dart';
import '../../data/categories.dart';
import '../../providers/booking_flow_provider.dart';

class ReservarPage extends ConsumerWidget {
  const ReservarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(bookingFlowProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final isTablet = WebBreakpoints.isTablet(constraints.maxWidth);

        if (isDesktop || isTablet) {
          // Two-column layout
          final leftFlex = isDesktop ? 6 : 55;
          final rightFlex = isDesktop ? 4 : 45;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: leftFlex,
                child: _ActiveStep(flowState: flowState),
              ),
              Expanded(
                flex: rightFlex,
                child: _SummarySidebar(flowState: flowState),
              ),
            ],
          );
        }

        // Mobile: full width + sticky bottom bar
        return Stack(
          children: [
            _ActiveStep(flowState: flowState),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyBottomBar(flowState: flowState),
            ),
          ],
        );
      },
    );
  }
}
```

The `_ActiveStep` widget switches on `flowState.step` and renders the correct step widget. The `_CategoryGrid` shows 7 category cards in a responsive grid (4 desktop, 3 tablet, 2 mobile).

The `_SummarySidebar` builds progressively — showing selected category, service, answers, salon, price as each step completes. It's a `Card` with a `Column` of summary rows.

The `_StickyBottomBar` (mobile only) shows a compact summary + action button.

**Step 3: Update router to use ReservarPage**

In `lib/config/router.dart`, replace lines 356-360:

```dart
// Old:
GoRoute(
  path: WebRoutes.reservar,
  builder: (context, state) =>
      const _Placeholder(WebRoutes.reservar),
),

// New:
GoRoute(
  path: WebRoutes.reservar,
  builder: (context, state) => const ReservarPage(),
),
```

Add import at top: `import '../pages/client/reservar_page.dart';`

**Step 4: Verify it builds and renders**

Run: `/home/bc/flutter/bin/flutter build web --no-tree-shake-icons` from `beautycita_web/`
Navigate to `/reservar` — should show category grid instead of "Proximamente"

**Step 5: Commit**

```bash
git add lib/pages/client/reservar_page.dart lib/shells/client_shell.dart lib/config/router.dart
git commit -m "feat(web): reservar page with category grid and two-column layout"
```

---

## Task 3: Service Selection (Step 2)

**Files:**
- Modify: `lib/pages/client/reservar_page.dart` — add `_ServiceSelection` widget

**Step 1: Build the subcategory chips + service list**

When a category is selected, animate in:
1. A horizontal `Wrap` of `ChoiceChip` widgets for subcategories
2. Below: a `ListView` of `ListTile` widgets for service items within the selected subcategory
3. Each ListTile shows: service name (Spanish), and tapping it calls `ref.read(bookingFlowProvider.notifier).selectService(sub, item)`

Use `AnimatedSwitcher` for smooth transitions between steps.

**Step 2: Verify subcategory → service selection works**

Run web, navigate to `/reservar`, tap a category, see chips appear, tap a subcategory, see services, tap a service → flow advances to follow-up step.

**Step 3: Commit**

```bash
git add lib/pages/client/reservar_page.dart
git commit -m "feat(web): subcategory chips and service selection for reservar flow"
```

---

## Task 4: Follow-up Questions (Step 3)

**Files:**
- Modify: `lib/pages/client/reservar_page.dart` — add `_FollowUpQuestions` widget
- Modify: `lib/providers/booking_flow_provider.dart` — add follow-up fetching logic

**Step 1: Fetch follow-up questions from service_profiles**

When the flow enters `BookingStep.followUp`, query Supabase:
```dart
final response = await BCSupabase.client
    .from('service_profiles')
    .select('max_follow_up_questions')
    .eq('service_type', serviceType)
    .maybeSingle();
```

If `max_follow_up_questions == 0` or null, skip directly to results (`skipFollowUps()`).

Otherwise, fetch from `follow_up_questions` table:
```dart
final questions = await BCSupabase.client
    .from('follow_up_questions')
    .select()
    .eq('service_type', serviceType)
    .order('question_order');
```

**Step 2: Build the follow-up question cards**

Render each `FollowUpQuestion` as a card with the appropriate input type:
- `visual_cards`: Grid of image cards (each `FollowUpOption` with optional image_url)
- `date_picker`: Date selection widget
- `yes_no`: Two large buttons (Sí / No)

After all questions answered, call `submitFollowUps()` to advance to results.

**Step 3: Commit**

```bash
git add lib/pages/client/reservar_page.dart lib/providers/booking_flow_provider.dart
git commit -m "feat(web): follow-up questions step for reservar flow"
```

---

## Task 5: Curate Engine Call + Results Display (Step 4, Path A)

**Files:**
- Create: `lib/providers/curate_provider.dart` — edge function call
- Modify: `lib/pages/client/reservar_page.dart` — add `_ResultCards` widget

**Step 1: Create the curate provider**

```dart
// lib/providers/curate_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';

Future<CurateResponse> callCurateEngine({
  required String serviceType,
  required double lat,
  required double lng,
  Map<String, String>? followUpAnswers,
  String? userId,
}) async {
  final request = CurateRequest(
    serviceType: serviceType,
    location: LatLng(lat: lat, lng: lng),
    transportMode: 'car', // Always assume car for ranking
    followUpAnswers: followUpAnswers,
    userId: userId,
  );

  final response = await BCSupabase.client.functions.invoke(
    'curate-results',
    body: request.toJson(),
  );

  if (response.status != 200) {
    throw Exception('Engine error: ${response.status}');
  }

  return CurateResponse.fromJson(response.data as Map<String, dynamic>);
}
```

**Step 2: Build result cards**

Each `ResultCard` displays in a `Card` widget:
- Left: salon photo (or placeholder)
- Center column: salon name, stylist name + avatar, rating stars + review count, service price + duration, best slot date/time, travel time
- Right: review snippet (if available)
- Bottom: large "RESERVAR" `ElevatedButton`
- Below all 3 cards: "Ver más salones cerca de ti" `TextButton` → calls `showDiscovered()`

Use the `ResultCard` model from `beautycita_core/models.dart` — it has `business`, `staff`, `service`, `slot`, `transport`, `reviewSnippet` fields.

**Step 3: Wire up the engine call**

When `BookingStep.results` is entered and `isLoading` is true, trigger `callCurateEngine()` with the selected service type + user location + follow-up answers. On response, call `setCurateResponse()`. If results are empty, automatically fetch discovered salons.

**Step 4: Commit**

```bash
git add lib/providers/curate_provider.dart lib/pages/client/reservar_page.dart
git commit -m "feat(web): curate engine integration and result cards for reservar"
```

---

## Task 6: Discovered Salons Fallback (Step 4, Path B)

**Files:**
- Modify: `lib/pages/client/reservar_page.dart` — add `_DiscoveredSalonsList` widget
- Modify: `lib/providers/booking_flow_provider.dart` — add discovered salon fetching

**Step 1: Fetch nearby discovered salons**

Query `discovered_salons` by location + category:
```dart
// Use PostGIS to find nearby salons in the selected category
final response = await BCSupabase.client.rpc('nearby_discovered_salons', params: {
  'user_lat': lat,
  'user_lng': lng,
  'category_filter': selectedCategory.id,
  'result_limit': 20,
});
```

If this RPC doesn't exist, fall back to a direct query:
```dart
final response = await BCSupabase.client
    .from('discovered_salons')
    .select('business_name, location_address, phone, whatsapp_verified, categories, feature_image_url')
    .ilike('categories', '%${selectedCategory.nameEs}%')
    .not('phone', 'is', null)
    .limit(20);
```

**Step 2: Build WhatsApp-style invite list**

Header: "Estos salones aún no están en BeautyCita. ¡Invítalos!"

Each row in a `ListView`:
- Salon name (bold)
- Address (secondary text)
- WhatsApp verified badge (green checkmark) if `whatsapp_verified == true`
- "Invitar" `OutlinedButton` on the right

Tapping "Invitar" calls the BeautyCita WA API (port 3200) via an edge function to send a WhatsApp invitation message to the salon on behalf of the user.

**Step 3: Commit**

```bash
git add lib/pages/client/reservar_page.dart lib/providers/booking_flow_provider.dart
git commit -m "feat(web): discovered salons fallback with WhatsApp invite"
```

---

## Task 7: Stripe.js Web Integration

**Files:**
- Modify: `web/index.html` — add Stripe.js script tag
- Create: `lib/services/stripe_web.dart` — Dart interop with Stripe.js

**Step 1: Add Stripe.js to index.html**

In `web/index.html`, add before the closing `</head>`:
```html
<script src="https://js.stripe.com/v3/"></script>
```

**Step 2: Create Dart JS interop wrapper**

```dart
// lib/services/stripe_web.dart
import 'dart:js_interop';

@JS('Stripe')
external JSObject _createStripe(JSString publishableKey);

@JS()
@staticInterop
class StripeJS {}

extension StripeJSExt on StripeJS {
  external JSObject elements([JSObject? options]);
  external JSPromise confirmPayment(JSObject params);
}

class StripeWeb {
  late final StripeJS _stripe;
  JSObject? _elements;
  JSObject? _cardElement;

  StripeWeb(String publishableKey) {
    _stripe = _createStripe(publishableKey.toJS) as StripeJS;
  }

  /// Mount a card element into a DOM container with the given ID.
  void mountCardElement(String containerId) {
    _elements = _stripe.elements();
    // Create card element via JS interop
    // Mount into #containerId
  }

  /// Confirm a payment intent using the mounted card element.
  Future<Map<String, dynamic>> confirmPayment(String clientSecret) async {
    // Call stripe.confirmPayment({clientSecret, elements, ...})
    // Return result
    throw UnimplementedError('Implement with full JS interop');
  }

  void dispose() {
    // Unmount card element
  }
}
```

Note: The exact JS interop calls will need to use `dart:js_interop` extensions. The implementer should reference the Stripe.js docs for `stripe.elements()`, `elements.create('payment')`, `element.mount('#id')`, and `stripe.confirmPayment()`.

**Step 3: Commit**

```bash
git add web/index.html lib/services/stripe_web.dart
git commit -m "feat(web): Stripe.js interop for web payments"
```

---

## Task 8: Payment Step (Step 5)

**Files:**
- Modify: `lib/pages/client/reservar_page.dart` — add `_PaymentStep` widget
- Create: `lib/providers/payment_provider.dart` — payment intent creation

**Step 1: Build the payment step UI**

Two sections side by side on desktop, stacked on mobile:

**Left (or top on mobile): Booking Summary**
- Service name + category
- Salon name + address
- Stylist name
- Date + time
- Duration

**Right (or bottom on mobile): Payment**
- Price display (large, bold)
- Stripe card element mounted via `HtmlElementView` with `platformViewRegistry`
- OXXO tab option (secondary)
- "Confirmar y Pagar — $XXX MXN" button

**Step 2: Create payment provider**

```dart
// lib/providers/payment_provider.dart
import 'package:beautycita_core/supabase.dart';

Future<Map<String, dynamic>> createPaymentIntent({
  required String serviceId,
  required String businessId,
  required String staffId,
  required String scheduledAt,
  required int amountCents,
  required String userId,
}) async {
  final response = await BCSupabase.client.functions.invoke(
    'create-payment-intent',
    body: {
      'service_id': serviceId,
      'business_id': businessId,
      'staff_id': staffId,
      'scheduled_at': scheduledAt,
      'amount': amountCents,
      'user_id': userId,
      'payment_type': 'full',
      'payment_method': 'card',
    },
  );

  if (response.status != 200) {
    throw Exception('Payment error: ${response.status}');
  }

  return response.data as Map<String, dynamic>;
}
```

**Step 3: Auth gate**

Before showing the payment form, check if user is authenticated:
```dart
final user = BCSupabase.client.auth.currentUser;
if (user == null) {
  // Show inline phone verification widget
  // Phone input -> OTP verification -> continue to payment
}
```

Build `_PhoneVerification` widget:
- Phone number input field (pre-formatted for MX +52)
- "Enviar código" button → calls `BCSupabase.client.auth.signInWithOtp(phone: ...)`
- 6-digit OTP input field
- "Verificar" button → calls `BCSupabase.client.auth.verifyOTP(...)`

**Step 4: Wire payment confirmation**

On "Confirmar y Pagar" tap:
1. Call `createPaymentIntent()` → get `client_secret`
2. Call `StripeWeb.confirmPayment(clientSecret)`
3. On success: create appointment record in DB, call `setBookingConfirmed(appointmentId)`
4. On failure: show error message

**Step 5: Commit**

```bash
git add lib/pages/client/reservar_page.dart lib/providers/payment_provider.dart
git commit -m "feat(web): payment step with Stripe.js Elements and phone auth gate"
```

---

## Task 9: Post-Booking Transport (Step 6) + Confirmation

**Files:**
- Modify: `lib/pages/client/reservar_page.dart` — add `_TransportStep` and `_ConfirmationView`

**Step 1: Build transport selection**

"¿Cómo llegarás?" with 3 large option cards:
- 🚗 Carro → show Google Maps directions link (opens in new tab)
- 🚕 Uber → prompt to connect Uber (future feature), for now show "Próximamente"
- 🚌 Transporte Público → show transit directions link

On selection, update appointment with transport_mode:
```dart
await BCSupabase.client
    .from('appointments')
    .update({'transport_mode': mode})
    .eq('id', bookingId);
```

Then advance to `BookingStep.confirmed`.

**Step 2: Build confirmation view**

Animated success state:
- Green checkmark animation
- "¡Reservación confirmada!" heading
- Booking ID
- Summary: service, salon, date/time, price paid
- Salon contact info (WhatsApp link if available)
- "Hacer otra reservación" button → `reset()`
- "Ver mis citas" button → navigate to `/mis-citas`

**Step 3: Commit**

```bash
git add lib/pages/client/reservar_page.dart
git commit -m "feat(web): post-booking transport and confirmation view"
```

---

## Task 10: Summary Sidebar + Mobile Sticky Bar

**Files:**
- Modify: `lib/pages/client/reservar_page.dart` — flesh out `_SummarySidebar` and `_StickyBottomBar`

**Step 1: Build progressive summary sidebar**

Right column (desktop/tablet), shows items as they're selected with slide-in animation:

```
┌─────────────────────────┐
│  Tu Reservación          │
│                          │
│  ✂️ Cabello > Corte      │  ← after step 2
│  Corte Mujer             │
│                          │
│  📋 Preferencias         │  ← after step 3 (if follow-ups)
│  Largo: Medio            │
│                          │
│  🏪 Salon Bonita         │  ← after step 4
│  Ana García ⭐ 4.8       │
│  Mar 4, 2:00 PM          │
│                          │
│  💰 $350 MXN             │  ← after step 4
│  45 min · 2.3 km         │
│                          │
└─────────────────────────┘
```

Use `AnimatedSize` + `AnimatedOpacity` for smooth reveals.

**Step 2: Build mobile sticky bottom bar**

Compact bar at bottom of screen (mobile only):
- Left: selected service name + price (if known)
- Right: action button ("Continuar" / "Reservar" / "Pagar")
- Height: 72px with top border shadow

Only show when there's something to summarize (step >= service).

**Step 3: Commit**

```bash
git add lib/pages/client/reservar_page.dart
git commit -m "feat(web): progressive summary sidebar and mobile sticky bar"
```

---

## Task 11: Geolocation

**Files:**
- Create: `lib/services/geolocation_web.dart`
- Modify: `lib/pages/client/reservar_page.dart` — request location on page load

**Step 1: Create geolocation service**

```dart
// lib/services/geolocation_web.dart
import 'dart:js_interop';
import 'dart:async';

@JS('navigator.geolocation.getCurrentPosition')
external void _getCurrentPosition(JSFunction success, JSFunction error);

Future<(double lat, double lng)> getWebLocation() async {
  final completer = Completer<(double, double)>();

  _getCurrentPosition(
    ((JSObject position) {
      final coords = position['coords'] as JSObject;
      final lat = (coords['latitude'] as JSNumber).toDartDouble;
      final lng = (coords['longitude'] as JSNumber).toDartDouble;
      completer.complete((lat, lng));
    }).toJS,
    ((JSObject error) {
      completer.completeError('Location access denied');
    }).toJS,
  );

  return completer.future;
}
```

**Step 2: Request on page load**

In `ReservarPage.build()`, use a `ref.listen` or `initState` equivalent to request location when the page first loads. Store in the booking flow state via `setLocation(lat, lng)`.

If denied, show a banner: "Necesitamos tu ubicación para encontrar salones cercanos" with a "Permitir" button to retry.

**Step 3: Commit**

```bash
git add lib/services/geolocation_web.dart lib/pages/client/reservar_page.dart
git commit -m "feat(web): browser geolocation for salon proximity"
```

---

## Task 12: Polish + Production Ready

**Files:**
- All files created above

**Step 1: Visual polish**

- Ensure all text is in Spanish
- Add `flutter_animate` transitions between steps (fade + slide)
- Loading states: use `LoadingSkeleton` during engine call
- Error states: use `EmptyState` widget with retry button
- Category cards: add hover effects on desktop (elevation change + scale)
- Result cards: add subtle hover effect + border highlight on desktop
- Responsive: test all 3 breakpoints (1400px, 900px, 375px)
- Colors: use `theme.colorScheme.primary` (#660033) for CTAs, gold (#FFB300) for accents
- Typography: headings in Poppins, body in Nunito (from theme)

**Step 2: Edge cases**

- No internet: show error state with retry
- Engine returns 0 results + no discovered salons nearby: "No encontramos salones para este servicio en tu zona. ¡Pronto tendremos más opciones!"
- Payment fails: show error, allow retry without losing selections
- Phone verification timeout: show "Reenviar código" after 60s
- Back navigation: each step has a back arrow/button, uses `goBack()` on provider

**Step 3: Build and deploy**

```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --release --no-tree-shake-icons
rsync -avz --delete build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(web): complete reservar page — production ready"
```

---

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `lib/providers/booking_flow_provider.dart` | Create | State management for entire booking flow |
| `lib/providers/curate_provider.dart` | Create | Curate engine edge function call |
| `lib/providers/payment_provider.dart` | Create | Payment intent creation |
| `lib/services/stripe_web.dart` | Create | Stripe.js interop for web payments |
| `lib/services/geolocation_web.dart` | Create | Browser geolocation API wrapper |
| `lib/pages/client/reservar_page.dart` | Create | Main reservar page with all step widgets |
| `lib/shells/client_shell.dart` | Modify | Add top nav bar with brand |
| `lib/config/router.dart` | Modify | Replace placeholder with ReservarPage |
| `web/index.html` | Modify | Add Stripe.js script tag |

## Dependencies

No new pub dependencies needed. Uses existing:
- `flutter_riverpod` — state management
- `beautycita_core` — models, theme, Supabase client
- `flutter_animate` — animations
- `dart:js_interop` — Stripe.js + geolocation (built-in)
