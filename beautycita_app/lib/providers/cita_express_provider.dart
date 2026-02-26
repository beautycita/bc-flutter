import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curate_result.dart';
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
  confirming,
  booking,
  booked,
  error,
  // nearbyResults removed — walk-in QR is always at THIS salon
}

class CitaExpressState {
  final CitaExpressStep step;
  final String businessId;
  final Map<String, dynamic>? businessInfo;
  final List<Map<String, dynamic>> services;
  final String? selectedServiceId;
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
    this.selectedServiceId,
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
    String? selectedServiceId,
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
      selectedServiceId: selectedServiceId ?? this.selectedServiceId,
      selectedServiceType: selectedServiceType ?? this.selectedServiceType,
      selectedServiceName: selectedServiceName ?? this.selectedServiceName,
      curateResponse: curateResponse ?? this.curateResponse,
      selectedResult: selectedResult ?? this.selectedResult,
      bookingId: bookingId ?? this.bookingId,
      error: error,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final citaExpressProvider =
    StateNotifierProvider.autoDispose<CitaExpressNotifier, CitaExpressState>(
  (ref) => CitaExpressNotifier(BookingRepository()),
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class CitaExpressNotifier extends StateNotifier<CitaExpressState> {
  final BookingRepository _bookingRepo;

  CitaExpressNotifier(this._bookingRepo) : super(const CitaExpressState());

  /// Load business info + services for the scanned salon.
  Future<void> loadBusiness(String businessId) async {
    state = state.copyWith(
      step: CitaExpressStep.loading,
      businessId: businessId,
    );

    try {
      final client = SupabaseClientService.client;

      // Walk-in QR: only require verified (business may not be "active" in search yet).
      final bizResponse = await client
          .from('businesses')
          .select('*, services(*)')
          .eq('id', businessId)
          .eq('is_verified', true)
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

  /// User selected a service. Find available walk-in slots directly.
  Future<void> selectService(String serviceId, String displayName) async {
    // Get category from the loaded service data
    final svcData = state.services.firstWhere(
      (s) => s['id'] == serviceId,
      orElse: () => <String, dynamic>{},
    );

    state = state.copyWith(
      step: CitaExpressStep.searching,
      selectedServiceId: serviceId,
      selectedServiceName: displayName,
      selectedServiceType: svcData['category'] as String? ?? '',
    );

    await _findWalkInSlots(serviceId: serviceId, range: 'today');
  }

  /// No slots today — try this week at the same salon.
  Future<void> tryOtherDay() async {
    state = state.copyWith(step: CitaExpressStep.searching);
    await _findWalkInSlots(
      serviceId: state.selectedServiceId!,
      range: 'this_week',
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
        staffId: result.staff.id,
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
  // Internal — Direct availability query (bypasses engine)
  // ---------------------------------------------------------------------------

  Future<void> _findWalkInSlots({
    required String serviceId,
    required String range,
  }) async {
    try {
      final client = SupabaseClientService.client;

      // Get service details from loaded services
      final svcData = state.services.firstWhere(
        (s) => s['id'] == serviceId,
        orElse: () => <String, dynamic>{},
      );
      if (svcData.isEmpty) {
        state = state.copyWith(
          step: CitaExpressStep.error,
          error: 'Servicio no encontrado',
        );
        return;
      }

      final baseDuration = svcData['duration_minutes'] as int? ?? 60;
      final buffer = svcData['buffer_minutes'] as int? ?? 0;
      final basePrice = (svcData['price'] as num?)?.toDouble() ?? 0.0;

      // Calculate time window
      final now = DateTime.now();
      final DateTime windowEnd;

      if (range == 'today') {
        windowEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else {
        // this_week: through end of Sunday
        final daysUntilSunday = DateTime.sunday - now.weekday;
        final endDay = daysUntilSunday <= 0
            ? now.add(Duration(days: 7 + daysUntilSunday))
            : now.add(Duration(days: daysUntilSunday));
        windowEnd = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);
      }

      // Find staff who can perform this service
      final staffRows = await client
          .from('staff_services')
          .select(
            'staff_id, custom_price, custom_duration, '
            'staff!inner(id, first_name, last_name, avatar_url, '
            'average_rating, total_reviews)',
          )
          .eq('service_id', serviceId)
          .eq('staff.is_active', true)
          .eq('staff.accept_online_booking', true);

      if ((staffRows as List).isEmpty) {
        state = state.copyWith(step: CitaExpressStep.noSlotsToday);
        return;
      }

      // Business info for result cards
      final biz = state.businessInfo ?? {};
      final bizInfo = BusinessInfo(
        id: state.businessId,
        name: biz['name'] as String? ?? 'Salon',
        photoUrl: biz['photo_url'] as String?,
        address: biz['address'] as String?,
        lat: (biz['lat'] as num?)?.toDouble() ?? 0,
        lng: (biz['lng'] as num?)?.toDouble() ?? 0,
      );

      // For each staff member, find their first available slot
      final results = <ResultCard>[];

      for (final row in staffRows) {
        final staff = row['staff'] as Map<String, dynamic>;
        final staffId = row['staff_id'] as String;
        final effectivePrice =
            (row['custom_price'] as num?)?.toDouble() ?? basePrice;
        final effectiveDuration =
            (row['custom_duration'] as int?) ?? baseDuration;

        final slotsResponse = await client.rpc(
          'find_available_slots',
          params: {
            'p_staff_id': staffId,
            'p_duration_minutes': effectiveDuration + buffer,
            'p_window_start': now.toUtc().toIso8601String(),
            'p_window_end': windowEnd.toUtc().toIso8601String(),
          },
        );

        final slots = slotsResponse as List;
        if (slots.isEmpty) continue;

        // Take the first available slot for this staff member
        final slotStartStr = slots[0]['slot_start'] as String;
        final slotStart = DateTime.parse(slotStartStr);
        final slotEnd =
            slotStart.add(Duration(minutes: effectiveDuration));

        final firstName = staff['first_name'] as String? ?? '';
        final lastName = staff['last_name'] as String? ?? '';
        final staffName = lastName.isNotEmpty
            ? '$firstName ${lastName[0]}.'
            : firstName;

        results.add(ResultCard(
          rank: results.length + 1,
          score: 1.0,
          business: bizInfo,
          staff: StaffInfo(
            id: staffId,
            name: staffName,
            avatarUrl: staff['avatar_url'] as String?,
            experienceYears: null,
            rating: (staff['average_rating'] as num?)?.toDouble() ?? 0,
            totalReviews: (staff['total_reviews'] as int?) ?? 0,
          ),
          service: ServiceInfo(
            id: serviceId,
            name: state.selectedServiceName ?? '',
            price: effectivePrice,
            durationMinutes: effectiveDuration,
            currency: 'MXN',
          ),
          slot: SlotInfo(
            startsAt: slotStart.toUtc().toIso8601String(),
            endsAt: slotEnd.toUtc().toIso8601String(),
          ),
          transport: const TransportInfo(
            mode: 'walk_in',
            durationMin: 0,
            distanceKm: 0,
            trafficLevel: 'none',
          ),
          badges: const ['walk_in_ok'],
          areaAvgPrice: effectivePrice,
          scoringBreakdown: const ScoringBreakdown(
            proximity: 1.0,
            availability: 1.0,
            rating: 0.5,
            price: 0.5,
            portfolio: 0.5,
          ),
        ));
      }

      if (results.isEmpty) {
        state = state.copyWith(step: CitaExpressStep.noSlotsToday);
        return;
      }

      // Sort by slot time (soonest first)
      results.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));

      final step = range == 'today'
          ? CitaExpressStep.results
          : CitaExpressStep.futureResults;

      state = state.copyWith(
        step: step,
        curateResponse: CurateResponse(
          bookingWindow: BookingWindowInfo(
            primaryDate: now.toIso8601String().split('T')[0],
            primaryTime: now.toIso8601String(),
            windowStart: now.toUtc().toIso8601String(),
            windowEnd: windowEnd.toUtc().toIso8601String(),
          ),
          results: results,
        ),
      );
    } catch (e) {
      debugPrint('[CitaExpress] Walk-in slots error: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error buscando disponibilidad: $e',
      );
    }
  }
}
