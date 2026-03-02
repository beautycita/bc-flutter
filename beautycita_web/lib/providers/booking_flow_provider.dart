import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart';

// ── Booking step enum ────────────────────────────────────────────────────────

enum BookingStep {
  category,
  service,
  followUp,
  results,
  payment,
  transport,
  confirmed,
}

// ── Booking flow state ───────────────────────────────────────────────────────

@immutable
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
    // Explicit clear flags for nullable fields
    bool clearCategory = false,
    bool clearSubcategory = false,
    bool clearService = false,
    bool clearCurateResponse = false,
    bool clearSelectedResult = false,
    bool clearTransportMode = false,
    bool clearBookingId = false,
    bool clearError = false,
  }) {
    return BookingFlowState(
      step: step ?? this.step,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedSubcategory: clearSubcategory
          ? null
          : (selectedSubcategory ?? this.selectedSubcategory),
      selectedService:
          clearService ? null : (selectedService ?? this.selectedService),
      followUpAnswers: followUpAnswers ?? this.followUpAnswers,
      curateResponse: clearCurateResponse
          ? null
          : (curateResponse ?? this.curateResponse),
      selectedResult:
          clearSelectedResult ? null : (selectedResult ?? this.selectedResult),
      discoveredSalons: discoveredSalons ?? this.discoveredSalons,
      showingDiscovered: showingDiscovered ?? this.showingDiscovered,
      transportMode:
          clearTransportMode ? null : (transportMode ?? this.transportMode),
      bookingId: clearBookingId ? null : (bookingId ?? this.bookingId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
    );
  }
}

// ── Booking flow notifier ────────────────────────────────────────────────────

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  BookingFlowNotifier() : super(const BookingFlowState());

  /// Select a category. Resets all downstream state, preserves location.
  void selectCategory(ServiceCategory category) {
    state = BookingFlowState(
      step: BookingStep.service,
      selectedCategory: category,
      userLat: state.userLat,
      userLng: state.userLng,
    );
  }

  /// Select subcategory + service item. Advances to follow-up step.
  void selectService(ServiceSubcategory sub, ServiceItem item) {
    state = state.copyWith(
      selectedSubcategory: sub,
      selectedService: item,
      step: BookingStep.followUp,
      clearCurateResponse: true,
      clearSelectedResult: true,
      followUpAnswers: const {},
      discoveredSalons: const [],
      showingDiscovered: false,
      clearTransportMode: true,
      clearBookingId: true,
      clearError: true,
    );
  }

  /// Skip follow-up questions entirely. Advances to results + loading.
  void skipFollowUps() {
    state = state.copyWith(
      step: BookingStep.results,
      isLoading: true,
      clearError: true,
    );
  }

  /// Record a single follow-up answer.
  void answerFollowUp(String key, String value) {
    state = state.copyWith(
      followUpAnswers: {...state.followUpAnswers, key: value},
    );
  }

  /// Submit all follow-up answers. Advances to results + loading.
  void submitFollowUps() {
    state = state.copyWith(
      step: BookingStep.results,
      isLoading: true,
      clearError: true,
    );
  }

  /// Store the curate engine response. Shows discovered fallback if empty.
  void setCurateResponse(CurateResponse response) {
    state = state.copyWith(
      curateResponse: response,
      isLoading: false,
      showingDiscovered: response.results.isEmpty,
    );
  }

  /// Store discovered salons (fallback when engine returns empty).
  void setDiscoveredSalons(List<Map<String, dynamic>> salons) {
    state = state.copyWith(
      discoveredSalons: salons,
      showingDiscovered: true,
      isLoading: false,
    );
  }

  /// Switch to showing discovered salons view.
  void showDiscovered() {
    state = state.copyWith(showingDiscovered: true);
  }

  /// Hide discovered salons and return to curated results.
  void hideDiscovered() {
    state = state.copyWith(showingDiscovered: false);
  }

  /// Select a result card. Advances to payment step.
  void selectResult(ResultCard result) {
    state = state.copyWith(
      selectedResult: result,
      step: BookingStep.payment,
    );
  }

  /// Set loading state.
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Set error (clears loading).
  void setError(String? message) {
    if (message == null) {
      state = state.copyWith(isLoading: false, clearError: true);
    } else {
      state = state.copyWith(error: message, isLoading: false);
    }
  }

  /// Mark booking as confirmed. Advances to transport step.
  void setBookingConfirmed(String bookingId) {
    state = state.copyWith(
      bookingId: bookingId,
      step: BookingStep.transport,
      isLoading: false,
    );
  }

  /// Set transport mode. Advances to confirmed step.
  void setTransportMode(String mode) {
    state = state.copyWith(
      transportMode: mode,
      step: BookingStep.confirmed,
    );
  }

  /// Store user location.
  void setLocation(double lat, double lng) {
    state = state.copyWith(userLat: lat, userLng: lng);
  }

  /// Navigate one step backward, clearing downstream state.
  void goBack() {
    switch (state.step) {
      case BookingStep.service:
        state = BookingFlowState(
          step: BookingStep.category,
          userLat: state.userLat,
          userLng: state.userLng,
        );
      case BookingStep.followUp:
        state = state.copyWith(
          step: BookingStep.service,
          clearService: true,
          clearSubcategory: true,
          followUpAnswers: const {},
          clearCurateResponse: true,
          clearSelectedResult: true,
          discoveredSalons: const [],
          showingDiscovered: false,
          clearTransportMode: true,
          clearBookingId: true,
          clearError: true,
          isLoading: false,
        );
      case BookingStep.results:
        state = state.copyWith(
          step: BookingStep.followUp,
          clearCurateResponse: true,
          clearSelectedResult: true,
          discoveredSalons: const [],
          showingDiscovered: false,
          clearTransportMode: true,
          clearBookingId: true,
          clearError: true,
          isLoading: false,
        );
      case BookingStep.payment:
        state = state.copyWith(
          step: BookingStep.results,
          clearSelectedResult: true,
          clearTransportMode: true,
          clearBookingId: true,
          clearError: true,
          isLoading: false,
        );
      case BookingStep.transport:
        state = state.copyWith(
          step: BookingStep.payment,
          clearTransportMode: true,
          clearError: true,
          isLoading: false,
        );
      case BookingStep.confirmed:
        // Don't go back from confirmed — user must reset.
        break;
      case BookingStep.category:
        // Already at the beginning — nothing to do.
        break;
    }
  }

  /// Reset to initial state, preserving location.
  void reset() {
    state = BookingFlowState(
      userLat: state.userLat,
      userLng: state.userLng,
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final bookingFlowProvider =
    StateNotifierProvider<BookingFlowNotifier, BookingFlowState>(
  (ref) => BookingFlowNotifier(),
);
