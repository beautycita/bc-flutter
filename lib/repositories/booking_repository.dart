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

    final data = {
      'user_id': userId,
      'provider_id': providerId,
      'provider_service_id': providerServiceId,
      'service_name': serviceName,
      'category': category,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'price': price,
      'notes': notes,
      'status': 'pending',
    };

    final response = await SupabaseClientService.client
        .from('bookings')
        .insert(data)
        .select()
        .single();

    return Booking.fromJson(response);
  }

  /// Get the current user's bookings, optionally filtered by status,
  /// joined with the provider name, ordered by scheduled_at descending.
  Future<List<Booking>> getUserBookings({String? status}) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    var query = SupabaseClientService.client
        .from('bookings')
        .select('*, providers(name)')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('scheduled_at', ascending: false);

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get upcoming bookings (scheduled in the future, not cancelled).
  Future<List<Booking>> getUpcomingBookings() async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now().toIso8601String();

    final response = await SupabaseClientService.client
        .from('bookings')
        .select('*, providers(name)')
        .eq('user_id', userId)
        .neq('status', 'cancelled')
        .gte('scheduled_at', now)
        .order('scheduled_at');

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Cancel a booking by setting its status to 'cancelled'.
  Future<void> cancelBooking(String bookingId) async {
    await SupabaseClientService.client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
  }

  /// Update the status of a booking.
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await SupabaseClientService.client
        .from('bookings')
        .update({'status': status})
        .eq('id', bookingId);
  }
}
