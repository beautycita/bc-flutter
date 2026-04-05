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
      if (staffId != null) 'staff_id': staffId,
      if (paymentIntentId != null) 'payment_intent_id': paymentIntentId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (transportMode != null) 'transport_mode': transportMode,
      'booking_source': bookingSource,
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

  /// Cancel a booking with cancellation policy enforcement.
  ///
  /// Rules:
  /// - If cancelled BEFORE the salon's cancellation_hours deadline → full refund minus BC 3% commission
  /// - If cancelled AFTER the deadline → deposit forfeited, remaining refunded minus BC 3% commission
  /// - BC's 3% commission is NEVER refunded
  /// - Returns a CancelResult with what happened
  Future<CancelResult> cancelBooking(String bookingId) async {
    // Fetch booking + business cancellation policy
    final booking = await SupabaseClientService.client
        .from('appointments')
        .select('id, user_id, price, payment_status, payment_method, starts_at, business_id, businesses(cancellation_hours, deposit_percentage, deposit_required)')
        .eq('id', bookingId)
        .maybeSingle();

    if (booking == null) return CancelResult(refundAmount: 0, depositForfeited: 0, commissionKept: 0, isFreeCancel: true);

    final price = (booking['price'] as num?)?.toDouble() ?? 0;
    final isPaid = booking['payment_status'] == 'paid';
    final startsAt = DateTime.tryParse(booking['starts_at'] as String? ?? '');
    final biz = booking['businesses'] as Map<String, dynamic>?;
    final cancellationHours = biz?['cancellation_hours'] as int? ?? 24;
    final depositRequired = biz?['deposit_required'] as bool? ?? false;
    final depositPct = (biz?['deposit_percentage'] as num?)?.toDouble() ?? 0;

    // Calculate time until appointment
    final now = DateTime.now().toUtc();
    final hoursUntilAppt = startsAt != null ? startsAt.toUtc().difference(now).inHours : 999;
    final isFreeCancel = hoursUntilAppt >= cancellationHours;

    // BC 3% commission is NEVER refunded
    final bcCommission = price * 0.03;

    double refundAmount;
    double depositForfeited = 0;

    if (!isPaid || price <= 0) {
      // Not paid — just cancel, no money to move
      refundAmount = 0;
    } else if (isFreeCancel) {
      // Cancelled within free window — full refund minus BC commission
      refundAmount = price - bcCommission;
    } else if (depositRequired && depositPct > 0) {
      // Late cancel — deposit forfeited, refund the rest minus BC commission
      final depositAmount = price * (depositPct / 100);
      depositForfeited = depositAmount;
      refundAmount = (price - depositAmount - bcCommission).clamp(0, double.infinity);
    } else {
      // Late cancel, no deposit policy — full refund minus BC commission
      refundAmount = price - bcCommission;
    }

    // Update appointment status
    String paymentStatus = booking['payment_status'] as String? ?? 'unpaid';
    if (isPaid) {
      paymentStatus = refundAmount > 0 ? 'refunded_to_saldo' : 'deposit_forfeited';
    }

    await SupabaseClientService.client
        .from('appointments')
        .update({
          'status': 'cancelled_customer',
          'payment_status': paymentStatus,
          'updated_at': now.toIso8601String(),
        })
        .eq('id', bookingId);

    // Refund to saldo (the calculated amount, not full price)
    if (isPaid && refundAmount > 0) {
      final userId = booking['user_id'] as String?;
      if (userId != null) {
        await SupabaseClientService.adjustSaldo(userId: userId, amount: refundAmount);
      }
    }

    // Record the 3% commission BC kept on cancellation (audit trail)
    if (isPaid && bcCommission > 0) {
      final bizId = booking['business_id'] as String?;
      if (bizId != null) {
        await SupabaseClientService.client.from('commission_records').insert({
          'business_id': bizId,
          'appointment_id': bookingId,
          'amount': double.parse(bcCommission.toStringAsFixed(2)),
          'rate': 0.03,
          'source': 'cancellation',
          'period_month': DateTime.now().month,
          'period_year': DateTime.now().year,
          'status': 'collected',
        }).then((_) {}).catchError((_) {});
      }
    }

    return CancelResult(
      refundAmount: refundAmount,
      depositForfeited: depositForfeited,
      commissionKept: isPaid ? bcCommission : 0,
      isFreeCancel: isFreeCancel,
    );
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
