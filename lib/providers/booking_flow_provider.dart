import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curate_result.dart';
import '../models/follow_up_question.dart';
import '../repositories/booking_repository.dart';
import '../services/curate_service.dart';
import '../services/follow_up_service.dart';
import '../services/places_service.dart';
import '../services/uber_service.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'user_preferences_provider.dart';

// ---------------------------------------------------------------------------
// Service instances
// ---------------------------------------------------------------------------

final curateServiceProvider = Provider((ref) => CurateService());
final followUpServiceProvider = Provider((ref) => FollowUpService());
final bookingRepositoryProvider = Provider((ref) => BookingRepository());
final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});
final uberServiceProvider = Provider((ref) {
  final clientId = dotenv.env['UBER_CLIENT_ID'] ?? '';
  final redirectUri = dotenv.env['UBER_REDIRECT_URI'] ?? 'beautycita://uber-callback';
  final sandbox = dotenv.env['UBER_SANDBOX'] == 'true';
  return UberService(clientId: clientId, redirectUri: redirectUri, sandbox: sandbox);
});

// ---------------------------------------------------------------------------
// Booking Flow State
// ---------------------------------------------------------------------------

enum BookingFlowStep {
  categorySelect,
  subcategorySelect,
  followUpQuestions,
  transportSelect,
  loading,
  results,
  confirmation,
  booking,  // creating appointment + scheduling rides
  booked,   // success — booking confirmed
  error,
}

class BookingFlowState {
  final BookingFlowStep step;
  final String? serviceType;
  final String? serviceName;
  final String? transportMode;
  final LatLng? userLocation;
  final CurateResponse? curateResponse;
  final OverrideWindow? overrideWindow;
  final ResultCard? selectedResult;
  final String? error;
  final List<FollowUpQuestion> followUpQuestions;
  final int currentQuestionIndex;
  final Map<String, String> followUpAnswers;
  final String? bookingId;
  final bool uberScheduled;

  const BookingFlowState({
    this.step = BookingFlowStep.categorySelect,
    this.serviceType,
    this.serviceName,
    this.transportMode,
    this.userLocation,
    this.curateResponse,
    this.overrideWindow,
    this.selectedResult,
    this.error,
    this.followUpQuestions = const [],
    this.currentQuestionIndex = 0,
    this.followUpAnswers = const {},
    this.bookingId,
    this.uberScheduled = false,
  });

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
    CurateResponse? curateResponse,
    OverrideWindow? overrideWindow,
    bool clearOverrideWindow = false,
    ResultCard? selectedResult,
    String? error,
    List<FollowUpQuestion>? followUpQuestions,
    int? currentQuestionIndex,
    Map<String, String>? followUpAnswers,
    String? bookingId,
    bool? uberScheduled,
  }) {
    return BookingFlowState(
      step: step ?? this.step,
      serviceType: serviceType ?? this.serviceType,
      serviceName: serviceName ?? this.serviceName,
      transportMode: transportMode ?? this.transportMode,
      userLocation: userLocation ?? this.userLocation,
      curateResponse: curateResponse ?? this.curateResponse,
      overrideWindow: clearOverrideWindow ? null : (overrideWindow ?? this.overrideWindow),
      selectedResult: selectedResult ?? this.selectedResult,
      error: error,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      followUpAnswers: followUpAnswers ?? this.followUpAnswers,
      bookingId: bookingId ?? this.bookingId,
      uberScheduled: uberScheduled ?? this.uberScheduled,
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
  final UberService _uberService;
  final UserPrefsState _userPrefs;

  BookingFlowNotifier(
    this._curateService,
    this._followUpService,
    this._bookingRepo,
    this._uberService,
    this._userPrefs,
  ) : super(const BookingFlowState());

  /// User selected a service type from the category tree.
  /// Checks for follow-up questions before proceeding.
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
        state = state.copyWith(
          step: BookingFlowStep.transportSelect,
        );
      }
    } catch (_) {
      // If fetching questions fails, just skip to transport
      state = state.copyWith(
        step: BookingFlowStep.transportSelect,
      );
    }
  }

  /// User answered a follow-up question. Advance to next or to transport.
  void answerFollowUp(String questionKey, String value) {
    final newAnswers = Map<String, String>.from(state.followUpAnswers);
    newAnswers[questionKey] = value;

    final nextIndex = state.currentQuestionIndex + 1;

    if (nextIndex < state.followUpQuestions.length) {
      state = state.copyWith(
        currentQuestionIndex: nextIndex,
        followUpAnswers: newAnswers,
      );
    } else {
      state = state.copyWith(
        step: BookingFlowStep.transportSelect,
        followUpAnswers: newAnswers,
      );
    }
  }

  /// User selected a transport mode — triggers the API call.
  Future<void> selectTransport(String mode, LatLng location) async {
    state = state.copyWith(
      step: BookingFlowStep.loading,
      transportMode: mode,
      userLocation: location,
    );

    await _fetchResults();
  }

  /// User tapped "¿Otro horario?" — re-fetch with override window.
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

  /// User tapped RESERVAR on a result card.
  void selectResult(ResultCard result) {
    state = state.copyWith(
      step: BookingFlowStep.confirmation,
      selectedResult: result,
    );
  }

  /// User confirmed the booking — create appointment + schedule Uber if needed.
  Future<void> confirmBooking() async {
    final result = state.selectedResult;
    if (result == null) return;

    state = state.copyWith(step: BookingFlowStep.booking);

    try {
      // 1. Create the appointment
      final booking = await _bookingRepo.createBooking(
        providerId: result.business.id,
        providerServiceId: result.service.id,
        serviceName: result.service.name,
        category: state.serviceType ?? '',
        scheduledAt: result.slot.startTime,
        durationMinutes: result.service.durationMinutes,
        price: result.service.price,
      );

      bool uberOk = false;

      // 2. If transport is uber, schedule rides
      if (state.transportMode == 'uber' && state.userLocation != null) {
        try {
          final uberResult = await _uberService.scheduleRides(
            appointmentId: booking.id,
            pickupLat: state.userLocation!.lat,
            pickupLng: state.userLocation!.lng,
            salonLat: result.business.lat,
            salonLng: result.business.lng,
            salonAddress: result.business.address,
            appointmentAt: result.slot.startTime.toUtc().toIso8601String(),
            durationMinutes: result.service.durationMinutes,
          );
          uberOk = uberResult.scheduled;
          if (!uberOk) {
            debugPrint('Uber scheduling skipped: ${uberResult.reason}');
          }
        } catch (e) {
          debugPrint('Uber scheduling error: $e');
          // Booking was created, Uber just didn't work — don't fail the whole thing
        }
      }

      state = state.copyWith(
        step: BookingFlowStep.booked,
        bookingId: booking.id,
        uberScheduled: uberOk,
      );
    } catch (e) {
      state = state.copyWith(
        step: BookingFlowStep.error,
        error: 'No se pudo crear la cita: $e',
      );
    }
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
      case BookingFlowStep.transportSelect:
        if (state.followUpQuestions.isNotEmpty) {
          state = state.copyWith(
            step: BookingFlowStep.followUpQuestions,
            currentQuestionIndex: state.followUpQuestions.length - 1,
          );
        } else {
          state = state.copyWith(
            step: BookingFlowStep.categorySelect,
            serviceType: null,
            serviceName: null,
          );
        }
      case BookingFlowStep.results:
      case BookingFlowStep.error:
        state = state.copyWith(
          step: BookingFlowStep.transportSelect,
          curateResponse: null,
          error: null,
        );
      case BookingFlowStep.confirmation:
        state = state.copyWith(
          step: BookingFlowStep.results,
          selectedResult: null,
        );
      case BookingFlowStep.booked:
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
        transportMode: state.transportMode!,
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
      state = state.copyWith(
        step: BookingFlowStep.error,
        error: e.toString(),
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
  final uberService = ref.watch(uberServiceProvider);
  final userPrefs = ref.read(userPrefsProvider);
  return BookingFlowNotifier(
    curateService,
    followUpService,
    bookingRepo,
    uberService,
    userPrefs,
  );
});
