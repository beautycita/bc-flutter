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
  }) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final endsAt = scheduledAt.add(Duration(minutes: durationMinutes));

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
      'status': 'pending',
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

  /// Cancel a booking by setting its status to 'cancelled_customer'.
  Future<void> cancelBooking(String bookingId) async {
    await SupabaseClientService.client
        .from('appointments')
        .update({'status': 'cancelled_customer'})
        .eq('id', bookingId);
  }

  /// Update the status of a booking.
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await SupabaseClientService.client
        .from('appointments')
        .update({'status': status})
        .eq('id', bookingId);
  }
}
