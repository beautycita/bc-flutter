import 'package:beautycita/models/booking.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/behavior_event_service.dart';

class BookingRepository {
  /// Create a new booking for the currently authenticated user.
  ///
  /// Routes through [create_booking_with_financials] RPC so that every booking
  /// has corresponding commission_records and tax_withholdings rows.
  Future<String> createBooking({
    required String providerId,
    String? providerServiceId,
    required String serviceName,
    required String category,
    required DateTime scheduledAt,
    int durationMinutes = 60,
    double? price,
    String? notes,
    String? paymentMethod,
    String? transportMode,
    String? staffId,
    String bookingSource = 'salon_direct',
  }) async {
    // Validate inputs
    if (durationMinutes <= 0) throw Exception('Duracion invalida');
    if (price != null && price < 0) throw Exception('Precio invalido');

    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Verify salon is still active and verified
    final biz = await SupabaseClientService.client
        .from(BCTables.businesses)
        .select('is_active, is_verified, stripe_charges_enabled')
        .eq('id', providerId)
        .maybeSingle();
    if (biz == null || biz['is_active'] != true || biz['is_verified'] != true) {
      throw Exception('Este salon no esta disponible para reservas');
    }

    final endsAt = scheduledAt.add(Duration(minutes: durationMinutes));

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
        // p_idempotency_key and p_deposit_amount use RPC defaults
      },
    );

    // RPC returns the inserted row as a record or single-element list.
    if (response == null) {
      throw Exception('create_booking_with_financials returned null');
    }
    final row = response is List
        ? (response.isEmpty ? null : response.first)
        : response;
    if (row == null) {
      throw Exception('create_booking_with_financials returned empty result');
    }
    final bookingId = row['booking_id'] as String?;
    if (bookingId == null) {
      throw Exception(
          'create_booking_with_financials returned no booking_id: $row');
    }
    return bookingId;
  }

  /// Get the current user's bookings, optionally filtered by status,
  /// joined with the business name, ordered by starts_at descending.
  Future<List<Booking>> getUserBookings({String? status}) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      return [];
    }

    var query = SupabaseClientService.client
        .from(BCTables.appointments)
        .select('*, businesses(name)')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('starts_at', ascending: false);

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get upcoming bookings (scheduled in the future, not cancelled).
  Future<List<Booking>> getUpcomingBookings() async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      return [];
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final response = await SupabaseClientService.client
        .from(BCTables.appointments)
        .select('*, businesses(name)')
        .eq('user_id', userId)
        .not('status', 'in', '(cancelled_customer,cancelled_business)')
        .gte('starts_at', now)
        .order('starts_at');

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Cancel a booking with cancellation policy enforcement.
  ///
  /// Rules:
  /// - If cancelled BEFORE the salon's cancellation_hours deadline → full refund minus BC 3% commission
  /// - If cancelled AFTER the deadline → deposit forfeited, remaining refunded minus BC 3% commission
  /// - BC's 3% commission is NEVER refunded
  /// - Returns a CancelResult with what happened
  Future<CancelResult> cancelBooking(String bookingId) async {
    // Atomic server-side: ownership check, refund calc, saldo credit, commission
    final result = await SupabaseClientService.client.rpc('cancel_booking', params: {
      'p_booking_id': bookingId,
      'p_cancelled_by': 'customer',
    }) as Map<String, dynamic>;

    BehaviorEventService.instance.bookingCancelled(bookingId: bookingId);

    return CancelResult(
      refundAmount: (result['refund_amount'] as num?)?.toDouble() ?? 0,
      depositForfeited: (result['deposit_forfeited'] as num?)?.toDouble() ?? 0,
      commissionKept: (result['commission_kept'] as num?)?.toDouble() ?? 0,
      isFreeCancel: result['is_free_cancel'] as bool? ?? true,
    );
  }

  /// Update the status of a booking.
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await SupabaseClientService.client
        .from(BCTables.appointments)
        .update({'status': status})
        .eq('id', bookingId);
  }

  /// Get a single booking by ID with joined business name.
  Future<Booking?> getBookingById(String id) async {
    final response = await SupabaseClientService.client
        .from(BCTables.appointments)
        .select('*, businesses(name, phone, lat, lng, address)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Booking.fromJson(response);
  }

  /// Update the notes field on a booking.
  Future<void> updateNotes(String id, String notes) async {
    await SupabaseClientService.client
        .from(BCTables.appointments)
        .update({'notes': notes})
        .eq('id', id);
  }

  /// Update the transport_mode field on an appointment.
  Future<void> updateTransportMode(String id, String mode) async {
    await SupabaseClientService.client
        .from(BCTables.appointments)
        .update({'transport_mode': mode})
        .eq('id', id);
  }
}

/// Result of a booking cancellation.
class CancelResult {
  final double refundAmount;
  final double depositForfeited;
  final double commissionKept;
  final bool isFreeCancel;

  const CancelResult({
    required this.refundAmount,
    required this.depositForfeited,
    required this.commissionKept,
    required this.isFreeCancel,
  });
}
