import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curate_result.dart';
import '../services/curate_service.dart';
import '../services/supabase_client.dart';
import '../repositories/booking_repository.dart';

// ---------------------------------------------------------------------------
// Cita Express State Machine
// ---------------------------------------------------------------------------

enum CitaExpressStep {
  loading,
  serviceSelect,
  searching,
  results,
  noSlotsToday,
  futureResults,
  nearbyResults,
  confirming,
  booking,
  booked,
  error,
}

class CitaExpressState {
  final CitaExpressStep step;
  final String businessId;
  final Map<String, dynamic>? businessInfo;
  final List<Map<String, dynamic>> services;
  final String? selectedServiceType;
  final String? selectedServiceName;
  final CurateResponse? curateResponse;
  final ResultCard? selectedResult;
  final String? bookingId;
  final String? error;
  final String paymentMethod;

  const CitaExpressState({
    this.step = CitaExpressStep.loading,
    this.businessId = '',
    this.businessInfo,
    this.services = const [],
    this.selectedServiceType,
    this.selectedServiceName,
    this.curateResponse,
    this.selectedResult,
    this.bookingId,
    this.error,
    this.paymentMethod = 'card',
  });

  CitaExpressState copyWith({
    CitaExpressStep? step,
    String? businessId,
    Map<String, dynamic>? businessInfo,
    List<Map<String, dynamic>>? services,
    String? selectedServiceType,
    String? selectedServiceName,
    CurateResponse? curateResponse,
    ResultCard? selectedResult,
    String? bookingId,
    String? error,
    String? paymentMethod,
  }) {
    return CitaExpressState(
      step: step ?? this.step,
      businessId: businessId ?? this.businessId,
      businessInfo: businessInfo ?? this.businessInfo,
      services: services ?? this.services,
      selectedServiceType: selectedServiceType ?? this.selectedServiceType,
      selectedServiceName: selectedServiceName ?? this.selectedServiceName,
      curateResponse: curateResponse ?? this.curateResponse,
      selectedResult: selectedResult ?? this.selectedResult,
      bookingId: bookingId ?? this.bookingId,
      error: error,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  /// Business lat/lng for engine calls (user is at the salon).
  LatLng? get businessLocation {
    if (businessInfo == null) return null;
    final lat = businessInfo!['lat'] as num?;
    final lng = businessInfo!['lng'] as num?;
    if (lat == null || lng == null) return null;
    return LatLng(lat: lat.toDouble(), lng: lng.toDouble());
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final citaExpressProvider =
    StateNotifierProvider.autoDispose<CitaExpressNotifier, CitaExpressState>(
  (ref) => CitaExpressNotifier(
    CurateService(),
    BookingRepository(),
  ),
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class CitaExpressNotifier extends StateNotifier<CitaExpressState> {
  final CurateService _curateService;
  final BookingRepository _bookingRepo;

  CitaExpressNotifier(this._curateService, this._bookingRepo)
      : super(const CitaExpressState());

  /// Load business info + services for the scanned salon.
  Future<void> loadBusiness(String businessId) async {
    state = state.copyWith(
      step: CitaExpressStep.loading,
      businessId: businessId,
    );

    try {
      final client = SupabaseClientService.client;

      // Fetch business with its active services
      final bizResponse = await client
          .from('businesses')
          .select('*, services(*)')
          .eq('id', businessId)
          .eq('is_active', true)
          .maybeSingle();

      if (bizResponse == null) {
        state = state.copyWith(
          step: CitaExpressStep.error,
          error: 'Salon no encontrado',
        );
        return;
      }

      // Extract active services
      final rawServices =
          (bizResponse['services'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final activeServices =
          rawServices.where((s) => s['is_active'] == true).toList();

      if (activeServices.isEmpty) {
        state = state.copyWith(
          step: CitaExpressStep.error,
          error: 'Este salon no tiene servicios disponibles',
          businessInfo: bizResponse,
        );
        return;
      }

      state = state.copyWith(
        step: CitaExpressStep.serviceSelect,
        businessInfo: bizResponse,
        services: activeServices,
      );
    } catch (e) {
      debugPrint('[CitaExpress] Error loading business: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error cargando salon: $e',
      );
    }
  }

  /// User selected a service. Call engine for today's availability at this salon.
  Future<void> selectService(String serviceType, String displayName) async {
    state = state.copyWith(
      step: CitaExpressStep.searching,
      selectedServiceType: serviceType,
      selectedServiceName: displayName,
    );

    await _callEngine(
      serviceType: serviceType,
      businessId: state.businessId,
      overrideRange: 'today',
      onEmpty: CitaExpressStep.noSlotsToday,
      onResults: CitaExpressStep.results,
    );
  }

  /// No slots today — try this week at the same salon.
  Future<void> tryOtherDay() async {
    state = state.copyWith(step: CitaExpressStep.searching);

    await _callEngine(
      serviceType: state.selectedServiceType!,
      businessId: state.businessId,
      overrideRange: 'this_week',
      onEmpty: CitaExpressStep.noSlotsToday,
      onResults: CitaExpressStep.futureResults,
    );
  }

  /// No slots at this salon — search nearby salons for today.
  Future<void> searchNearby() async {
    state = state.copyWith(step: CitaExpressStep.searching);

    await _callEngine(
      serviceType: state.selectedServiceType!,
      businessId: null, // No business filter
      overrideRange: 'today',
      onEmpty: CitaExpressStep.noSlotsToday,
      onResults: CitaExpressStep.nearbyResults,
    );
  }

  /// Select a result card for booking.
  void selectResult(ResultCard result) {
    state = state.copyWith(
      step: CitaExpressStep.confirming,
      selectedResult: result,
    );
  }

  /// Go back to service selection.
  void backToServices() {
    state = state.copyWith(
      step: CitaExpressStep.serviceSelect,
      curateResponse: null,
      selectedResult: null,
    );
  }

  /// Go back to results from confirmation.
  void backToResults() {
    final prevStep = state.curateResponse != null
        ? CitaExpressStep.results
        : CitaExpressStep.serviceSelect;
    state = state.copyWith(step: prevStep, selectedResult: null);
  }

  /// Set payment method.
  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  /// Confirm and create the booking.
  Future<void> confirmBooking() async {
    final result = state.selectedResult;
    if (result == null) return;

    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Necesitas iniciar sesion para reservar',
      );
      return;
    }

    state = state.copyWith(step: CitaExpressStep.booking);

    try {
      final booking = await _bookingRepo.createBooking(
        providerId: result.business.id,
        providerServiceId: result.service.id,
        serviceName: result.service.name,
        category: state.selectedServiceType ?? '',
        scheduledAt: result.slot.startTime,
        durationMinutes: result.service.durationMinutes,
        price: result.service.price,
        paymentMethod: state.paymentMethod,
      );

      state = state.copyWith(
        step: CitaExpressStep.booked,
        bookingId: booking.id,
      );
    } catch (e) {
      debugPrint('[CitaExpress] Booking error: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error al crear la cita: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _callEngine({
    required String serviceType,
    required String? businessId,
    required String overrideRange,
    required CitaExpressStep onEmpty,
    required CitaExpressStep onResults,
  }) async {
    final location = state.businessLocation;
    if (location == null) {
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Ubicacion del salon no disponible',
      );
      return;
    }

    try {
      final userId = SupabaseClientService.currentUserId;

      final request = CurateRequest(
        serviceType: serviceType,
        userId: userId,
        location: location,
        transportMode: 'car', // At salon, ~0 travel
        overrideWindow: OverrideWindow(range: overrideRange),
        businessId: businessId,
      );

      final response = await _curateService.curateResults(request);

      if (response.results.isEmpty) {
        state = state.copyWith(
          step: onEmpty,
          curateResponse: response,
        );
      } else {
        state = state.copyWith(
          step: onResults,
          curateResponse: response,
        );
      }
    } on CurateException catch (e) {
      debugPrint('[CitaExpress] Engine error: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error del motor: ${e.message}',
      );
    } catch (e) {
      debugPrint('[CitaExpress] Unexpected error: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error inesperado: $e',
      );
    }
  }
}
