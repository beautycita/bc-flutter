import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, ThemeMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:beautycita/services/btcpay_service.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/curate_result.dart';
import '../models/follow_up_question.dart';
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
  final String paymentMethod; // 'card', 'oxxo', 'bitcoin'

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
      ToastService.showError('No pudimos obtener tu ubicacion');
      state = state.copyWith(
        step: BookingFlowStep.error,
        error: 'Activa el GPS y permite el acceso a ubicacion',
      );
      return;
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
        case 'bitcoin':
          await _confirmBitcoin(result);
        case 'oxxo':
          await _confirmStripe(result, oxxoOnly: true);
        default: // card
          await _confirmStripe(result, oxxoOnly: false);
      }
    } on StripeException catch (e) {
      debugPrint('[PAYMENT] Stripe error: ${e.error.localizedMessage}');
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
  Future<void> _confirmStripe(ResultCard result, {required bool oxxoOnly}) async {
    String? paymentIntentId;
    final serviceId = result.service.id;

    if (serviceId.isNotEmpty && result.service.price > 0) {
      debugPrint('[PAYMENT] Creating PaymentIntent (${oxxoOnly ? "oxxo" : "card"}) for service $serviceId');

      final piResponse = await SupabaseClientService.client.functions.invoke(
        'create-payment-intent',
        body: {
          'service_id': serviceId,
          'scheduled_at': result.slot.startTime.toUtc().toIso8601String(),
          'payment_type': 'full',
          'payment_method': oxxoOnly ? 'oxxo' : 'card',
        },
      );

      if (piResponse.status != 200) {
        final error = piResponse.data is Map
            ? piResponse.data['error'] ?? 'Payment error'
            : 'Payment error';
        throw Exception(error);
      }

      final piData = piResponse.data as Map<String, dynamic>;
      final clientSecret = piData['client_secret'] as String;
      paymentIntentId = piData['payment_intent_id'] as String;
      final customerId = piData['customer_id'] as String?;
      final ephemeralKey = piData['ephemeral_key'] as String?;

      debugPrint('[PAYMENT] PaymentIntent created: $paymentIntentId');

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
              componentBackground: Color(0xFFF5F5F5),
              componentBorder: Color(0xFFBDBDBD),
              componentDivider: Color(0xFFE0E0E0),
              primaryText: Color(0xFF000000),
              secondaryText: Color(0xFF424242),
              placeholderText: Color(0xFF9E9E9E),
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
              ),
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      debugPrint('[PAYMENT] Payment sheet completed');
    }

    // For OXXO: booking is pending until they pay at the store
    // For card: payment is instant
    final isPaid = !oxxoOnly;

    final booking = await _bookingRepo.createBooking(
      providerId: result.business.id,
      providerServiceId: result.service.id,
      serviceName: result.service.name,
      category: state.serviceType ?? '',
      scheduledAt: result.slot.startTime,
      durationMinutes: result.service.durationMinutes,
      price: result.service.price,
      paymentIntentId: paymentIntentId,
      paymentStatus: paymentIntentId != null ? (isPaid ? 'paid' : 'pending') : null,
      paymentMethod: state.paymentMethod,
      transportMode: state.transportMode,
    );

    // Fire booking confirmation + push (fire and forget)
    _sendBookingNotifications(booking.id);

    // Transition to email verification gate
    state = state.copyWith(
      step: BookingFlowStep.emailVerification,
      bookingId: booking.id,
    );
  }

  /// Bitcoin path — BTCPay invoice + external browser checkout.
  Future<void> _confirmBitcoin(ResultCard result) async {
    final serviceId = result.service.id;

    // Create booking first as pending
    final booking = await _bookingRepo.createBooking(
      providerId: result.business.id,
      providerServiceId: result.service.id,
      serviceName: result.service.name,
      category: state.serviceType ?? '',
      scheduledAt: result.slot.startTime,
      durationMinutes: result.service.durationMinutes,
      price: result.service.price,
      paymentStatus: 'pending',
      paymentMethod: 'bitcoin',
      transportMode: state.transportMode,
    );

    // Create BTCPay invoice
    final invoice = await BTCPayService.createInvoice(
      serviceId: serviceId,
      scheduledAt: result.slot.startTime.toUtc().toIso8601String(),
    );

    debugPrint('[PAYMENT] BTCPay invoice created: ${invoice.invoiceId}');

    // Store invoice ID on booking
    await _bookingRepo.updateNotes(
      booking.id,
      'btcpay_invoice:${invoice.invoiceId}',
    );

    // Open checkout in external browser
    final url = Uri.parse(invoice.checkoutLink);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }

    // Fire booking confirmation + push (fire and forget)
    _sendBookingNotifications(booking.id);

    // Transition to email verification gate
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

      debugPrint('[CURATE] request: ${request.toJson()}');

      final response = await _curateService.curateResults(request);

      debugPrint('[CURATE] results count: ${response.results.length}');

      state = state.copyWith(
        step: BookingFlowStep.results,
        curateResponse: response,
      );
    } catch (e, st) {
      debugPrint('[CURATE] ERROR: $e');
      debugPrint('[CURATE] STACK: $st');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(
        step: BookingFlowStep.error,
        error: msg,
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
