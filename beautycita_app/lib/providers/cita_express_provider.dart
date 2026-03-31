import 'dart:convert' as json_codec;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  confirming,
  booking,
  booked,
  nearbySearching,
  nearbyResults,
  error,
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
  final List<ResultCard>? nearbyAlternatives;

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
    this.paymentMethod = 'cash_direct',
    this.nearbyAlternatives,
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
    List<ResultCard>? nearbyAlternatives,
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
      nearbyAlternatives: nearbyAlternatives ?? this.nearbyAlternatives,
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
      if (kDebugMode) debugPrint('[CitaExpress] Error loading business: $e');
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
      // Cash direct: no Stripe processing, booking confirmed immediately.
      // BC still charges 3% commission + tax withholdings on ALL registered transactions.
      final isCashDirect = state.paymentMethod == 'cash_direct';
      final price = result.service.price ?? 0;

      final booking = await _bookingRepo.createBooking(
        providerId: result.business.id,
        providerServiceId: result.service.id ?? '',
        serviceName: result.service.name,
        category: state.selectedServiceType ?? '',
        scheduledAt: result.slot!.startTime,
        durationMinutes: result.service.durationMinutes,
        price: price,
        paymentMethod: state.paymentMethod,
        paymentStatus: isCashDirect ? 'paid' : null,
        staffId: result.staff?.id,
      );

      // For cash payments: record commission + tax withholding
      if (isCashDirect && price > 0) {
        final bizId = result.business.id;
        final taxBase = price / 1.16;
        final isrWithheld = taxBase * 0.025;
        final ivaWithheld = taxBase * 0.08;
        final commission = price * 0.03;

        // Update appointment with tax fields
        SupabaseClientService.client.from('appointments').update({
          'tax_base': double.parse(taxBase.toStringAsFixed(2)),
          'isr_withheld': double.parse(isrWithheld.toStringAsFixed(2)),
          'iva_withheld': double.parse(ivaWithheld.toStringAsFixed(2)),
          'provider_net': double.parse((price - isrWithheld - ivaWithheld).toStringAsFixed(2)),
        }).eq('id', booking.id).then((_) {}).catchError((_) {});

        // Record commission
        SupabaseClientService.client.from('commission_records').insert({
          'business_id': bizId,
          'appointment_id': booking.id,
          'amount': double.parse(commission.toStringAsFixed(2)),
          'rate': 0.03,
          'source': 'appointment',
          'period_month': DateTime.now().month,
          'period_year': DateTime.now().year,
          'status': 'collected',
        }).then((_) {}).catchError((_) {});

        // Record tax withholding
        SupabaseClientService.client.from('tax_withholdings').insert({
          'appointment_id': booking.id,
          'business_id': bizId,
          'payment_type': 'cash_direct',
          'jurisdiction': 'MX',
          'gross_amount': price,
          'tax_base': double.parse(taxBase.toStringAsFixed(2)),
          'iva_portion': double.parse((price - taxBase).toStringAsFixed(2)),
          'platform_fee': double.parse(commission.toStringAsFixed(2)),
          'isr_rate': 0.025,
          'iva_rate': 0.08,
          'isr_withheld': double.parse(isrWithheld.toStringAsFixed(2)),
          'iva_withheld': double.parse(ivaWithheld.toStringAsFixed(2)),
          'provider_net': double.parse((price - isrWithheld - ivaWithheld).toStringAsFixed(2)),
          'period_year': DateTime.now().year,
          'period_month': DateTime.now().month,
        }).then((_) {}).catchError((_) {});

        // Debt collection
        SupabaseClientService.client.rpc('calculate_payout_with_debt', params: {
          'p_business_id': bizId,
          'p_gross_amount': price,
          'p_commission': commission,
          'p_iva_withheld': ivaWithheld,
          'p_isr_withheld': isrWithheld,
        }).then((_) {}).catchError((_) {});
      }

      state = state.copyWith(
        step: CitaExpressStep.booked,
        bookingId: booking.id,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CitaExpress] Booking error: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error al crear la cita: $e',
      );
    }
  }

  /// Go back from nearby results to noSlotsToday.
  void backToNoSlots() {
    state = state.copyWith(
      step: CitaExpressStep.noSlotsToday,
      nearbyAlternatives: null,
    );
  }

  /// Select a nearby alternative and proceed to confirm.
  void selectNearbyResult(ResultCard result) {
    state = state.copyWith(
      step: CitaExpressStep.confirming,
      selectedResult: result,
    );
  }

  /// Find nearby salons with availability for the same service type.
  Future<void> findNearbyAlternatives() async {
    state = state.copyWith(step: CitaExpressStep.nearbySearching);

    try {
      // Request location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          step: CitaExpressStep.noSlotsToday,
          error: 'Necesitamos tu ubicacion para buscar salones cercanos',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      // Call curate-results with NO business_id → radius search + auto-expand
      final curateService = CurateService();
      final response = await curateService.curateResults(CurateRequest(
        serviceType: state.selectedServiceType ?? '',
        location: LatLng(lat: position.latitude, lng: position.longitude),
        transportMode: 'car',
        overrideWindow: const OverrideWindow(range: 'today'),
        // business_id intentionally NOT set → radius search
      ));

      // Filter out the original scanned salon
      final filtered = response.results
          .where((r) => r.business.id != state.businessId)
          .toList();

      if (filtered.isEmpty) {
        state = state.copyWith(
          step: CitaExpressStep.noSlotsToday,
          error: 'no_nearby_salons',
        );
        return;
      }

      state = state.copyWith(
        step: CitaExpressStep.nearbyResults,
        nearbyAlternatives: filtered.take(3).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CitaExpress] Nearby alternatives error: $e');
      state = state.copyWith(
        step: CitaExpressStep.noSlotsToday,
        error: 'Error buscando salones cercanos: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Business hours helper
  // ---------------------------------------------------------------------------

  static const _dayKeys = [
    'sunday', 'monday', 'tuesday', 'wednesday',
    'thursday', 'friday', 'saturday',
  ];

  /// Check if a slot falls within business hours.
  bool _isWithinBusinessHours(DateTime slotStart, DateTime slotEnd) {
    final biz = state.businessInfo;
    if (biz == null) return true; // no info = allow
    final hoursRaw = biz['hours'];
    if (hoursRaw == null) return true;

    Map<String, dynamic> hoursMap;
    if (hoursRaw is String) {
      try {
        hoursMap = Map<String, dynamic>.from(json_codec.jsonDecode(hoursRaw) as Map);
      } catch (_) {
        return true;
      }
    } else if (hoursRaw is Map) {
      hoursMap = Map<String, dynamic>.from(hoursRaw);
    } else {
      return true;
    }

    // Dart weekday: 1=Mon, 7=Sun. Map to day name keys.
    const dartDayKeys = ['', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayKey = dartDayKeys[slotStart.weekday];
    final dayData = hoursMap[dayKey];

    // Null or no open/close = closed that day
    if (dayData == null) return false;
    if (dayData is! Map) return false;

    final openStr = dayData['open'] as String?;
    final closeStr = dayData['close'] as String?;
    if (openStr == null || closeStr == null) return false;

    // Parse open/close times
    final openParts = openStr.split(':');
    final closeParts = closeStr.split(':');
    if (openParts.length < 2 || closeParts.length < 2) return false;

    final openHour = int.tryParse(openParts[0]) ?? 0;
    final openMin = int.tryParse(openParts[1]) ?? 0;
    final closeHour = int.tryParse(closeParts[0]) ?? 23;
    final closeMin = int.tryParse(closeParts[1]) ?? 59;

    final openTime = DateTime(slotStart.year, slotStart.month, slotStart.day, openHour, openMin);
    final closeTime = DateTime(slotStart.year, slotStart.month, slotStart.day, closeHour, closeMin);

    return !slotStart.isBefore(openTime) && !slotEnd.isAfter(closeTime);
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

      // Find staff who can perform this service.
      // Only owner and stylist positions are bookable — receptionists,
      // managers, and assistants must never appear in client-facing booking flows.
      final staffRows = await client
          .from('staff_services')
          .select(
            'staff_id, custom_price, custom_duration, '
            'staff!inner(id, first_name, last_name, avatar_url, '
            'average_rating, total_reviews, position)',
          )
          .eq('service_id', serviceId)
          .eq('staff.is_active', true)
          .eq('staff.accept_online_booking', true)
          .inFilter('staff.position', ['owner', 'stylist']);

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

        // Find the first slot that falls within business hours
        DateTime? slotStart;
        DateTime? slotEnd;
        for (final slot in slots) {
          final candidateStr = slot['slot_start'] as String;
          final candidate = DateTime.parse(candidateStr).toLocal();
          final candidateEnd = candidate.add(Duration(minutes: effectiveDuration));
          if (_isWithinBusinessHours(candidate, candidateEnd)) {
            slotStart = candidate;
            slotEnd = candidateEnd;
            break;
          }
        }
        if (slotStart == null || slotEnd == null) continue;

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
      results.sort((a, b) => (a.slot?.startTime ?? DateTime(2099)).compareTo(b.slot?.startTime ?? DateTime(2099)));

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
      if (kDebugMode) debugPrint('[CitaExpress] Walk-in slots error: $e');
      state = state.copyWith(
        step: CitaExpressStep.error,
        error: 'Error buscando disponibilidad: $e',
      );
    }
  }
}
