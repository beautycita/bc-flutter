// TODO: Add server-side cron job to auto-cancel orphaned pending bookings
// (status=pending, payment_status=pending, created_at > 30 min ago).
// Client-side cleanup is in main.dart but a cron is needed for reliability.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, ThemeMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:beautycita/services/toast_service.dart';
import '../models/curate_result.dart';
import '../models/follow_up_question.dart';
import '../models/booking.dart';
import '../repositories/booking_repository.dart';
import '../services/curate_service.dart';
import '../services/follow_up_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'user_preferences_provider.dart';
import 'profile_provider.dart' show tempSearchLocationProvider;

// ---------------------------------------------------------------------------
// Service instances
// ---------------------------------------------------------------------------

final curateServiceProvider = Provider((ref) => CurateService());
final followUpServiceProvider = Provider((ref) => FollowUpService());
final bookingRepositoryProvider = Provider((ref) => BookingRepository());
final placesServiceProvider = Provider<PlacesService>((ref) {
  final apiKey = dotenv.env['GOOGLE_ANDROID_API_KEY'] ?? '';
  return PlacesService(apiKey: apiKey);
});

// ---------------------------------------------------------------------------
// Booking Flow State
// ---------------------------------------------------------------------------

enum BookingFlowStep {
  categorySelect,
  subcategorySelect,
  followUpQuestions,
  loading,
  results,
  confirmation,
  booking,           // creating appointment + payment
  emailVerification, // post-payment email gate
  booked,            // success — booking confirmed
  error,
}

class BookingFlowState {
  final BookingFlowStep step;
  final String? serviceType;
  final String? serviceName;
  final String? transportMode;
  final LatLng? userLocation;
  final LatLng? customPickupLocation;
  final String? customPickupAddress;
  final CurateResponse? curateResponse;
  final OverrideWindow? overrideWindow;
  final ResultCard? selectedResult;
  final String? error;
  final List<FollowUpQuestion> followUpQuestions;
  final int currentQuestionIndex;
  final Map<String, String> followUpAnswers;
  final String? bookingId;
  final String paymentMethod; // 'card', 'oxxo'

  const BookingFlowState({
    this.step = BookingFlowStep.categorySelect,
    this.serviceType,
    this.serviceName,
    this.transportMode,
    this.userLocation,
    this.customPickupLocation,
    this.customPickupAddress,
    this.curateResponse,
    this.overrideWindow,
    this.selectedResult,
    this.error,
    this.followUpQuestions = const [],
    this.currentQuestionIndex = 0,
    this.followUpAnswers = const {},
    this.bookingId,
    this.paymentMethod = 'card',
  });

  /// Returns the pickup location: custom if set, otherwise user's GPS location.
  LatLng? get pickupLocation => customPickupLocation ?? userLocation;

  FollowUpQuestion? get currentQuestion {
    if (currentQuestionIndex < followUpQuestions.length) {
      return followUpQuestions[currentQuestionIndex];
    }
    return null;
  }

  BookingFlowState copyWith({
    BookingFlowStep? step,
    String? serviceType,
    String? serviceName,
    String? transportMode,
    LatLng? userLocation,
    LatLng? customPickupLocation,
    String? customPickupAddress,
    bool clearCustomPickup = false,
    CurateResponse? curateResponse,
    OverrideWindow? overrideWindow,
    bool clearOverrideWindow = false,
    ResultCard? selectedResult,
    String? error,
    List<FollowUpQuestion>? followUpQuestions,
    int? currentQuestionIndex,
    Map<String, String>? followUpAnswers,
    String? bookingId,
    String? paymentMethod,
  }) {
    return BookingFlowState(
      step: step ?? this.step,
      serviceType: serviceType ?? this.serviceType,
      serviceName: serviceName ?? this.serviceName,
      transportMode: transportMode ?? this.transportMode,
      userLocation: userLocation ?? this.userLocation,
      customPickupLocation: clearCustomPickup ? null : (customPickupLocation ?? this.customPickupLocation),
      customPickupAddress: clearCustomPickup ? null : (customPickupAddress ?? this.customPickupAddress),
      curateResponse: curateResponse ?? this.curateResponse,
      overrideWindow: clearOverrideWindow ? null : (overrideWindow ?? this.overrideWindow),
      selectedResult: selectedResult ?? this.selectedResult,
      error: error,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      followUpAnswers: followUpAnswers ?? this.followUpAnswers,
      bookingId: bookingId ?? this.bookingId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

// ---------------------------------------------------------------------------
// Booking Flow Notifier
// ---------------------------------------------------------------------------

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  final CurateService _curateService;
  final FollowUpService _followUpService;
  final BookingRepository _bookingRepo;
  final UserPrefsState _userPrefs;
  final LatLng? _tempSearchLocation;

  BookingFlowNotifier(
    this._curateService,
    this._followUpService,
    this._bookingRepo,
    this._userPrefs,
    this._tempSearchLocation,
  ) : super(const BookingFlowState());

  /// User selected a service type from the category tree.
  /// Checks for follow-up questions, then goes straight to engine.
  Future<void> selectService(String serviceType, String displayName) async {
    state = state.copyWith(
      step: BookingFlowStep.loading,
      serviceType: serviceType,
      serviceName: displayName,
    );

    try {
      final questions = await _followUpService.getQuestions(serviceType);

      if (questions.isNotEmpty) {
        state = state.copyWith(
          step: BookingFlowStep.followUpQuestions,
          followUpQuestions: questions,
          currentQuestionIndex: 0,
          followUpAnswers: {},
        );
      } else {
        // No follow-ups — go straight to engine
        await _acquireLocationAndFetch();
      }
    } catch (_) {
      // If fetching questions fails, go straight to engine
      await _acquireLocationAndFetch();
    }
  }

  /// User answered a follow-up question. Advance to next or to engine.
  Future<void> answerFollowUp(String questionKey, String value) async {
    final newAnswers = Map<String, String>.from(state.followUpAnswers);
    newAnswers[questionKey] = value;

    final nextIndex = state.currentQuestionIndex + 1;

    if (nextIndex < state.followUpQuestions.length) {
      state = state.copyWith(
        currentQuestionIndex: nextIndex,
        followUpAnswers: newAnswers,
      );
    } else {
      // Last answer — go to engine
      state = state.copyWith(
        step: BookingFlowStep.loading,
        followUpAnswers: newAnswers,
      );
      await _acquireLocationAndFetch();
    }
  }

  /// Acquire GPS location, set transport from prefs, then fetch results.
  Future<void> _acquireLocationAndFetch() async {
    // Use temp search location override if set, otherwise GPS
    LatLng? location;
    if (_tempSearchLocation != null) {
      location = LatLng(lat: _tempSearchLocation.lat, lng: _tempSearchLocation.lng);
    } else {
      location = await LocationService.getCurrentLocation();
    }

    if (location == null) {
      // Fallback: default to Puerto Vallarta so the flow doesn't hard-fail
      if (kDebugMode) debugPrint('[LOCATION] GPS unavailable, using Puerto Vallarta default');
      location = const LatLng(lat: 20.6534, lng: -105.2253);
    }

    // Use saved transport preference, default to 'car'
    final transport = _userPrefs.defaultTransport.isNotEmpty
        ? _userPrefs.defaultTransport
        : 'car';

    state = state.copyWith(
      step: BookingFlowStep.loading,
      userLocation: location,
      transportMode: transport,
    );

    await _fetchResults();
  }

  /// User selected a transport mode on the transport selection screen.
  Future<void> selectTransport(String mode, LatLng location) async {
    state = state.copyWith(
      step: BookingFlowStep.loading,
      transportMode: mode,
      userLocation: location,
    );
    await _fetchResults();
  }

  /// User tapped "Otro horario?" — re-fetch with override window.
  Future<void> overrideTime(OverrideWindow window) async {
    state = state.copyWith(
      step: BookingFlowStep.loading,
      overrideWindow: window,
    );

    await _fetchResults();
  }

  /// User tapped "Quitar filtro" — clear time override and re-fetch.
  Future<void> clearOverride() async {
    state = state.copyWith(
      step: BookingFlowStep.loading,
      clearOverrideWindow: true,
    );
    await _fetchResults();
  }

  /// User changed pickup location from the result card.
  void setPickupLocation(double lat, double lng, String address) {
    state = state.copyWith(
      customPickupLocation: LatLng(lat: lat, lng: lng),
      customPickupAddress: address,
    );
  }

  /// User tapped RESERVAR on a result card.
  void selectResult(ResultCard result) {
    state = state.copyWith(
      step: BookingFlowStep.confirmation,
      selectedResult: result,
    );
  }

  /// User selected a payment method on the confirmation screen.
  void selectPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  /// User confirmed the booking — route by payment method.
  Future<void> confirmBooking() async {
    final result = state.selectedResult;
    if (result == null) return;

    state = state.copyWith(step: BookingFlowStep.booking);

    try {
      switch (state.paymentMethod) {
        case 'saldo':
          await _confirmWithSaldo(result);
        case 'oxxo':
          await _confirmStripe(result, oxxoOnly: true);
        default: // card
          await _confirmStripe(result, oxxoOnly: false);
      }
    } on StripeException catch (e) {
      if (kDebugMode) debugPrint('[PAYMENT] Stripe error: ${e.error.localizedMessage}');
      final msg = e.error.code == FailureCode.Canceled
          ? 'Pago cancelado'
          : 'Error de pago: ${e.error.localizedMessage}';
      ToastService.showError(msg);
      state = state.copyWith(
        step: BookingFlowStep.confirmation,
        error: msg,
      );
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(
        step: BookingFlowStep.error,
        error: msg,
      );
    }
  }

  /// Card / OXXO path — Stripe PaymentSheet.
  ///
  /// IMPORTANT: Booking is created BEFORE payment to prevent the race condition
  /// where a user is charged but no appointment exists (e.g. app crash after
  /// payment but before booking creation). The webhook updates the booking
  /// to 'paid' + 'confirmed' on payment success.
  Future<void> _confirmStripe(ResultCard result, {required bool oxxoOnly}) async {
    final serviceId = result.service.id ?? '';

    // Step 1: Create booking first with pending status.
    // If payment fails or user cancels, we clean it up below.
    final booking = await _bookingRepo.createBooking(
      providerId: result.business.id,
      providerServiceId: result.service.id ?? '',
      serviceName: result.service.name,
      category: state.serviceType ?? '',
      scheduledAt: result.slot!.startTime,
      durationMinutes: result.service.durationMinutes,
      price: result.service.price ?? 0,
      paymentStatus: 'pending',
      paymentMethod: state.paymentMethod,
      transportMode: state.transportMode,
    );

    if (kDebugMode) debugPrint('[PAYMENT] Booking created: ${booking.id} (pending payment)');

    try {
      if (serviceId.isNotEmpty && (result.service.price ?? 0) > 0) {
        if (kDebugMode) debugPrint('[PAYMENT] Creating PaymentIntent (${oxxoOnly ? "oxxo" : "card"}) for service $serviceId');

        // Step 2: Create PaymentIntent with booking_id in metadata.
        // The webhook uses this to update the booking on payment success.
        final piResponse = await SupabaseClientService.client.functions.invoke(
          'create-payment-intent',
          body: {
            'service_id': serviceId,
            'booking_id': booking.id,
            'scheduled_at': result.slot!.startTime.toUtc().toIso8601String(),
            'payment_type': 'full',
            'payment_method': oxxoOnly ? 'oxxo' : 'card',
          },
        );

        if (piResponse.status != 200) {
          final error = piResponse.data is Map
              ? piResponse.data['error'] ?? 'Payment error'
              : 'Payment error';
          final errStr = error.toString().toLowerCase();
          // Surface a user-friendly message for Stripe Connect config issues
          if (errStr.contains('destination') ||
              errStr.contains('account') ||
              errStr.contains('connect') ||
              errStr.contains('pagos en linea')) {
            throw Exception(
              'Este salon aun no ha configurado pagos en linea. Contacta al salon directamente.',
            );
          }
          throw Exception(error);
        }

        final piData = piResponse.data as Map<String, dynamic>;
        final clientSecret = piData['client_secret'] as String;
        final paymentIntentId = piData['payment_intent_id'] as String;
        final customerId = piData['customer_id'] as String?;
        final ephemeralKey = piData['ephemeral_key'] as String?;

        if (kDebugMode) debugPrint('[PAYMENT] PaymentIntent created: $paymentIntentId');

        // Link the PaymentIntent to the booking so we can track it
        await SupabaseClientService.client
            .from('appointments')
            .update({'payment_intent_id': paymentIntentId})
            .eq('id', booking.id);

        // Step 3: Present payment sheet to user
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKey,
            merchantDisplayName: 'BeautyCita',
            returnURL: 'beautycita://stripe-redirect',
            allowsDelayedPaymentMethods: true,
            billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(
              name: CollectionMode.automatic,
              email: CollectionMode.never,
              phone: CollectionMode.never,
              address: AddressCollectionMode.never,
            ),
            style: ThemeMode.light,
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: Color(0xFF660033),
                background: Color(0xFFF9F9F9),
                componentBackground: Color(0xFFFFFFFF),
                componentBorder: Color(0xFFBDBDBD),
                componentDivider: Color(0xFFE0E0E0),
                primaryText: Color(0xFF000000),
                secondaryText: Color(0xFF212121),
                componentText: Color(0xFF000000),
                placeholderText: Color(0xFF757575),
                icon: Color(0xFF660033),
                error: Color(0xFFD32F2F),
              ),
              shapes: PaymentSheetShape(
                borderRadius: 12,
                borderWidth: 1.0,
              ),
              primaryButton: PaymentSheetPrimaryButtonAppearance(
                colors: PaymentSheetPrimaryButtonTheme(
                  light: PaymentSheetPrimaryButtonThemeColors(
                    background: Color(0xFF660033),
                    text: Color(0xFFFFFFFF),
                    border: Color(0xFF660033),
                  ),
                  dark: PaymentSheetPrimaryButtonThemeColors(
                    background: Color(0xFF660033),
                    text: Color(0xFFFFFFFF),
                    border: Color(0xFF660033),
                  ),
                ),
              ),
            ),
          ),
        );

        await Stripe.instance.presentPaymentSheet();
        if (kDebugMode) debugPrint('[PAYMENT] Payment sheet completed');

        // For card: payment is instant, webhook will confirm.
        // For OXXO: payment is pending until customer pays at store.
        if (!oxxoOnly) {
          // Card payment succeeded — update only if webhook hasn't already.
          // Conditional update prevents race with Stripe webhook.
          await SupabaseClientService.client
              .from('appointments')
              .update({
                'status': 'confirmed',
                'payment_status': 'paid',
              })
              .eq('id', booking.id)
              .eq('payment_status', 'pending');
        }
      }
    } on StripeException {
      // User cancelled or payment failed — cancel the booking
      if (kDebugMode) debugPrint('[PAYMENT] Stripe error, cancelling booking ${booking.id}');
      await _bookingRepo.cancelBooking(booking.id);
      rethrow;
    } catch (e) {
      // Any other error — cancel the booking
      if (kDebugMode) debugPrint('[PAYMENT] Error, cancelling booking ${booking.id}');
      await _bookingRepo.cancelBooking(booking.id);
      rethrow;
    }

    // Fire booking confirmation + push (fire and forget)
    _sendBookingNotifications(booking.id);

    // Transition to email verification gate
    state = state.copyWith(
      step: BookingFlowStep.emailVerification,
      bookingId: booking.id,
    );
  }


  /// Pay with saldo (user credit balance) — no Stripe involved.
  Future<void> _confirmWithSaldo(ResultCard result) async {
    final price = result.service.price ?? 0;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) throw Exception('No autenticado');

    // Verify saldo is sufficient
    final profile = await SupabaseClientService.client
        .from('profiles')
        .select('saldo')
        .eq('id', userId)
        .single();
    final saldo = (profile['saldo'] as num?)?.toDouble() ?? 0;
    if (saldo < price) {
      throw Exception('Saldo insuficiente (\$${saldo.toStringAsFixed(0)} < \$${price.toStringAsFixed(0)})');
    }

    // Create booking
    final booking = await _bookingRepo.createBooking(
      providerId: result.business.id,
      providerServiceId: result.service.id ?? '',
      serviceName: result.service.name,
      category: state.serviceType ?? '',
      scheduledAt: result.slot!.startTime,
      durationMinutes: result.service.durationMinutes,
      price: price,
      paymentStatus: 'paid',
      paymentMethod: 'saldo',
      transportMode: state.transportMode,
    );

    // Deduct saldo atomically (prevents race condition with concurrent bookings)
    await SupabaseClientService.adjustSaldo(userId: userId, amount: -price);

    // Mark as confirmed
    await SupabaseClientService.client
        .from('appointments')
        .update({
          'status': 'confirmed',
          'payment_status': 'paid',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', booking.id);

    // Calculate tax withholdings
    final taxBase = price / 1.16;
    final isrWithheld = taxBase * 0.025;
    final ivaWithheld = taxBase * 0.08;
    final providerNet = price - isrWithheld - ivaWithheld;
    await SupabaseClientService.client
        .from('appointments')
        .update({
          'tax_base': double.parse(taxBase.toStringAsFixed(2)),
          'isr_withheld': double.parse(isrWithheld.toStringAsFixed(2)),
          'iva_withheld': double.parse(ivaWithheld.toStringAsFixed(2)),
          'provider_net': double.parse(providerNet.toStringAsFixed(2)),
        })
        .eq('id', booking.id);

    // Record commission (3% service fee) — must not fail silently
    final commission = price * 0.03;
    try {
      await SupabaseClientService.client.from('commission_records').insert({
        'business_id': result.business.id,
        'appointment_id': booking.id,
        'amount': double.parse(commission.toStringAsFixed(2)),
        'rate': 0.03,
        'source': 'appointment',
        'period_month': DateTime.now().month,
        'period_year': DateTime.now().year,
        'status': 'collected',
      });
    } catch (e) {
      debugPrint('[CRITICAL] Commission insert failed for ${booking.id}: $e');
    }

    // Record tax withholding in ledger — must not fail silently
    try {
      await SupabaseClientService.client.from('tax_withholdings').insert({
        'appointment_id': booking.id,
        'business_id': result.business.id,
        'payment_type': 'saldo',
        'jurisdiction': 'MX',
        'gross_amount': price,
        'tax_base': double.parse(taxBase.toStringAsFixed(2)),
        'platform_fee': double.parse(commission.toStringAsFixed(2)),
        'isr_rate': 0.025,
        'iva_rate': 0.08,
        'isr_withheld': double.parse(isrWithheld.toStringAsFixed(2)),
        'iva_withheld': double.parse(ivaWithheld.toStringAsFixed(2)),
        'provider_net': double.parse(providerNet.toStringAsFixed(2)),
        'period_year': DateTime.now().year,
        'period_month': DateTime.now().month,
      });
    } catch (e) {
      debugPrint('[CRITICAL] Tax withholding insert failed for ${booking.id}: $e');
    }

    // Debt collection (if salon has outstanding debt)
    try {
      await SupabaseClientService.client.rpc('calculate_payout_with_debt', params: {
        'p_business_id': result.business.id,
        'p_gross_amount': price,
        'p_commission': commission,
        'p_iva_withheld': ivaWithheld,
        'p_isr_withheld': isrWithheld,
      });
    } catch (e) {
      debugPrint('[CRITICAL] Payout/debt calculation failed for ${booking.id}: $e');
    }

    _sendBookingNotifications(booking.id);

    state = state.copyWith(
      step: BookingFlowStep.emailVerification,
      bookingId: booking.id,
    );
  }

  /// Fire-and-forget booking notifications (push + multi-channel receipt).
  void _sendBookingNotifications(String bookingId) {
    // Push notification
    SupabaseClientService.client.functions.invoke(
      'send-push-notification',
      body: {
        'type': 'booking_confirmed',
        'user_id': SupabaseClientService.currentUserId,
        'booking_id': bookingId,
        'title': 'Cita confirmada',
        'body': '${state.serviceName ?? "Servicio"} reservado',
      },
    ).ignore();

    // Multi-channel receipt (email, WA, push)
    SupabaseClientService.client.functions.invoke(
      'booking-confirmation',
      body: {
        'booking_id': bookingId,
        'has_email': false, // Will be updated after email gate
      },
    ).ignore();
  }

  /// Called from email verification screen after user provides email or skips.
  void advanceFromEmail({bool hasEmail = false}) {
    if (hasEmail && state.bookingId != null) {
      // Re-send receipt with email
      SupabaseClientService.client.functions.invoke(
        'booking-confirmation',
        body: {
          'booking_id': state.bookingId,
          'has_email': true,
        },
      ).ignore();
    }

    state = state.copyWith(step: BookingFlowStep.booked);
  }

  /// Pre-fill the booking flow from a previous booking (rebook).
  /// Sets service type and jumps straight to location + engine fetch.
  Future<void> rebookFrom(Booking booking) async {
    state = BookingFlowState(
      step: BookingFlowStep.loading,
      serviceType: booking.serviceType ?? '',
      serviceName: booking.serviceName,
      transportMode: booking.transportMode,
    );
    await _acquireLocationAndFetch();
  }

  /// Reset back to category selection.
  void reset() {
    state = const BookingFlowState();
  }

  /// Go back one step.
  void goBack() {
    switch (state.step) {
      case BookingFlowStep.followUpQuestions:
        if (state.currentQuestionIndex > 0) {
          state = state.copyWith(
            currentQuestionIndex: state.currentQuestionIndex - 1,
          );
        } else {
          state = state.copyWith(
            step: BookingFlowStep.categorySelect,
            serviceType: null,
            serviceName: null,
            followUpQuestions: [],
            followUpAnswers: {},
          );
        }
      case BookingFlowStep.results:
      case BookingFlowStep.error:
        if (state.followUpQuestions.isNotEmpty) {
          state = state.copyWith(
            step: BookingFlowStep.followUpQuestions,
            currentQuestionIndex: state.followUpQuestions.length - 1,
            curateResponse: null,
            error: null,
          );
        } else {
          state = state.copyWith(
            step: BookingFlowStep.categorySelect,
            serviceType: null,
            serviceName: null,
            curateResponse: null,
            error: null,
          );
        }
      case BookingFlowStep.confirmation:
        state = state.copyWith(
          step: BookingFlowStep.results,
          selectedResult: null,
        );
      case BookingFlowStep.booked:
      case BookingFlowStep.emailVerification:
        // After booking is confirmed, go home (can't un-book from here)
        break;
      default:
        break;
    }
  }

  Future<void> _fetchResults() async {
    try {
      final request = CurateRequest(
        serviceType: state.serviceType!,
        userId: SupabaseClientService.currentUserId,
        location: state.userLocation!,
        transportMode: state.transportMode ?? _userPrefs.defaultTransport,
        followUpAnswers:
            state.followUpAnswers.isNotEmpty ? state.followUpAnswers : null,
        overrideWindow: state.overrideWindow,
        priceComfort: _userPrefs.priceComfort,
        qualitySpeed: _userPrefs.qualitySpeed,
        exploreLoyalty: _userPrefs.exploreLoyalty,
      );

      if (kDebugMode) debugPrint('[CURATE] request: ${request.toJson()}');

      final response = await _curateService.curateResults(request);

      if (kDebugMode) debugPrint('[CURATE] results count: ${response.results.length}');

      state = state.copyWith(
        step: BookingFlowStep.results,
        curateResponse: response,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[CURATE] ERROR: $e');
      if (kDebugMode) debugPrint('[CURATE] STACK: $st');

      // When curate fails (e.g. zero registered salons), show the results
      // screen with empty results → this triggers the discovered salons
      // invite flow instead of a dead-end error screen.
      state = state.copyWith(
        step: BookingFlowStep.results,
        curateResponse: CurateResponse(
          bookingWindow: BookingWindowInfo(
            primaryDate: DateTime.now().toIso8601String().split('T')[0],
            primaryTime: DateTime.now().toIso8601String(),
            windowStart: DateTime.now().toUtc().toIso8601String(),
            windowEnd: DateTime.now().add(const Duration(hours: 4)).toUtc().toIso8601String(),
          ),
          results: [],
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider Registration
// ---------------------------------------------------------------------------

final bookingFlowProvider =
    StateNotifierProvider<BookingFlowNotifier, BookingFlowState>((ref) {
  final curateService = ref.watch(curateServiceProvider);
  final followUpService = ref.watch(followUpServiceProvider);
  final bookingRepo = ref.watch(bookingRepositoryProvider);
  final userPrefs = ref.read(userPrefsProvider);
  final tempLoc = ref.read(tempSearchLocationProvider);
  // Convert PlaceLocation to LatLng if set
  final tempLatLng = tempLoc != null ? LatLng(lat: tempLoc.lat, lng: tempLoc.lng) : null;
  return BookingFlowNotifier(
    curateService,
    followUpService,
    bookingRepo,
    userPrefs,
    tempLatLng,
  );
});
