import 'package:beautycita/models/booking.dart';
import 'package:beautycita/services/supabase_client.dart';

class BookingRepository {
  /// Create a new booking for the currently authenticated user.
  Future<Booking> createBooking({
    required String providerId,
    String? providerServiceId,
    required String serviceName,
    required String category,
    required DateTime scheduledAt,
    int durationMinutes = 60,
    double? price,
    String? notes,
    String? paymentIntentId,
    String? paymentStatus,
    String? paymentMethod,
    String? transportMode,
    String? staffId,
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
        .from('businesses')
        .select('is_active, is_verified, stripe_charges_enabled')
        .eq('id', providerId)
        .maybeSingle();
    if (biz == null || biz['is_active'] != true || biz['is_verified'] != true) {
      throw Exception('Este salon no esta disponible para reservas');
    }

    final endsAt = scheduledAt.add(Duration(minutes: durationMinutes));

    // Map payment status to DB constraint values:
    // DB allows: unpaid, pending, paid, refunded, partial_refund, failed
    String dbPaymentStatus = 'unpaid';
    if (paymentStatus == 'paid') {
      dbPaymentStatus = 'paid';
    } else if (paymentStatus == 'pending_payment' || paymentStatus == 'pending') {
      dbPaymentStatus = 'pending';
    }

    final data = {
      'user_id': userId,
      'business_id': providerId,
      'service_id': providerServiceId,
      'service_name': serviceName,
      'service_type': category,
      'starts_at': scheduledAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'price': price,
      'notes': notes,
      'status': paymentStatus == 'paid' ? 'confirmed' : 'pending',
      'payment_status': dbPaymentStatus,
      'staff_id': ?staffId,
      'payment_intent_id': ?paymentIntentId,
      'payment_method': ?paymentMethod,
      'transport_mode': ?transportMode,
    };

    final response = await SupabaseClientService.client
        .from('appointments')
        .insert(data)
        .select()
        .single();

    return Booking.fromJson(response);
  }

  /// Get the current user's bookings, optionally filtered by status,
  /// joined with the business name, ordered by starts_at descending.
  Future<List<Booking>> getUserBookings({String? status}) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      return [];
    }

    var query = SupabaseClientService.client
        .from('appointments')
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
        .from('appointments')
        .select('*, businesses(name)')
        .eq('user_id', userId)
        .not('status', 'in', '(cancelled_customer,cancelled_business)')
        .gte('starts_at', now)
        .order('starts_at');

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Cancel a booking and refund to saldo if it was paid.
  Future<void> cancelBooking(String bookingId) async {
    // Fetch booking to check payment status
    final booking = await SupabaseClientService.client
        .from('appointments')
        .select('id, user_id, price, payment_status, payment_method')
        .eq('id', bookingId)
        .maybeSingle();

    // Update status
    await SupabaseClientService.client
        .from('appointments')
        .update({
          'status': 'cancelled_customer',
          'payment_status': booking?['payment_status'] == 'paid' ? 'refunded_to_saldo' : booking?['payment_status'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', bookingId);

    // Refund to saldo if paid (any method)
    if (booking != null &&
        booking['payment_status'] == 'paid' &&
        (booking['price'] as num?)?.toDouble() != null &&
        (booking['price'] as num).toDouble() > 0) {
      final userId = booking['user_id'] as String?;
      final amount = (booking['price'] as num).toDouble();
      if (userId != null) {
        await SupabaseClientService.client.rpc(
          'increment_saldo',
          params: {'p_user_id': userId, 'p_amount': amount},
        );
      }
    }
  }

  /// Update the status of a booking.
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await SupabaseClientService.client
        .from('appointments')
        .update({'status': status})
        .eq('id', bookingId);
  }

  /// Get a single booking by ID with joined business name.
  Future<Booking?> getBookingById(String id) async {
    final response = await SupabaseClientService.client
        .from('appointments')
        .select('*, businesses(name)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Booking.fromJson(response);
  }

  /// Update the notes field on a booking.
  Future<void> updateNotes(String id, String notes) async {
    await SupabaseClientService.client
        .from('appointments')
        .update({'notes': notes})
        .eq('id', id);
  }

  /// Update the transport_mode field on an appointment.
  Future<void> updateTransportMode(String id, String mode) async {
    await SupabaseClientService.client
        .from('appointments')
        .update({'transport_mode': mode})
        .eq('id', id);
  }
}
