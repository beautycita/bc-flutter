import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curate_result.dart';
import '../models/follow_up_question.dart';
import '../services/curate_service.dart';
import '../services/follow_up_service.dart';
import 'package:beautycita/services/supabase_client.dart';

// ---------------------------------------------------------------------------
// Service instances
// ---------------------------------------------------------------------------

final curateServiceProvider = Provider((ref) => CurateService());
final followUpServiceProvider = Provider((ref) => FollowUpService());

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
    ResultCard? selectedResult,
    String? error,
    List<FollowUpQuestion>? followUpQuestions,
    int? currentQuestionIndex,
    Map<String, String>? followUpAnswers,
  }) {
    return BookingFlowState(
      step: step ?? this.step,
      serviceType: serviceType ?? this.serviceType,
      serviceName: serviceName ?? this.serviceName,
      transportMode: transportMode ?? this.transportMode,
      userLocation: userLocation ?? this.userLocation,
      curateResponse: curateResponse ?? this.curateResponse,
      overrideWindow: overrideWindow ?? this.overrideWindow,
      selectedResult: selectedResult ?? this.selectedResult,
      error: error,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      followUpAnswers: followUpAnswers ?? this.followUpAnswers,
    );
  }
}

// ---------------------------------------------------------------------------
// Booking Flow Notifier
// ---------------------------------------------------------------------------

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  final CurateService _curateService;
  final FollowUpService _followUpService;

  BookingFlowNotifier(this._curateService, this._followUpService)
      : super(const BookingFlowState());

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

  /// User tapped RESERVAR on a result card.
  void selectResult(ResultCard result) {
    state = state.copyWith(
      step: BookingFlowStep.confirmation,
      selectedResult: result,
    );
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
  return BookingFlowNotifier(curateService, followUpService);
});
