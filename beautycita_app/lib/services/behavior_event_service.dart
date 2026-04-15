import 'package:beautycita_core/supabase.dart';
import 'package:flutter/foundation.dart';

/// Emits behavioral events to user_behavior_events table.
/// Lightweight, fire-and-forget. Never blocks UI.
class BehaviorEventService {
  BehaviorEventService._();
  static final instance = BehaviorEventService._();

  /// Cached opt-out status per user. Refreshed once per session.
  bool? _optedOut;
  String? _cachedUserId;

  /// Emit a behavioral event. Silent on failure.
  Future<void> emit({
    required String eventType,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
    String source = 'organic',
  }) async {
    try {
      if (!BCSupabase.isInitialized) return;
      final userId = BCSupabase.client.auth.currentUser?.id;
      if (userId == null) return;

      // Check opt-out (cached per session)
      if (_cachedUserId != userId) {
        _optedOut = null;
        _cachedUserId = userId;
      }
      if (_optedOut == null) {
        final profile = await BCSupabase.client
            .from(BCTables.profiles)
            .select('opted_out_analytics')
            .eq('id', userId)
            .maybeSingle();
        _optedOut = profile?['opted_out_analytics'] == true;
      }
      if (_optedOut == true) return;

      await BCSupabase.client.from(BCTables.userBehaviorEvents).insert({
        'user_id': userId,
        'event_type': eventType,
        'target_type': targetType,
        'target_id': targetId,
        'metadata': metadata ?? {},
        'source': source,
      });
    } catch (e) {
      debugPrint('[BehaviorEvent] $eventType failed: $e');
    }
  }

  // ── Convenience methods for common events ──

  void appOpened() => emit(eventType: 'app_opened', metadata: {'platform': 'mobile'});

  void bookingCreated({
    required String bookingId,
    required String businessId,
    String? serviceId,
    double? price,
    String? paymentMethod,
    String? city,
  }) => emit(
    eventType: 'booking_created',
    targetType: 'booking',
    targetId: bookingId,
    metadata: {
      'business_id': businessId,
      if (serviceId != null) 'service_id': serviceId,
      if (price != null) 'price': price,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (city != null) 'city': city,
    },
  );

  void bookingCancelled({
    required String bookingId,
    String? reason,
  }) => emit(
    eventType: 'booking_cancelled',
    targetType: 'booking',
    targetId: bookingId,
    metadata: {if (reason != null) 'reason': reason},
  );

  void reviewSubmitted({
    required String businessId,
    required int rating,
    String? appointmentId,
  }) => emit(
    eventType: 'review_submitted',
    targetType: 'salon',
    targetId: businessId,
    metadata: {
      'rating': rating,
      if (appointmentId != null) 'appointment_id': appointmentId,
    },
  );

  void inviteSent({
    required String salonId,
    String? salonName,
    String? city,
    String? state,
  }) => emit(
    eventType: 'invite_sent',
    targetType: 'salon',
    targetId: salonId,
    metadata: {
      if (salonName != null) 'salon_name': salonName,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
    },
  );

  void salonViewed({
    required String businessId,
    String? context,
    String? city,
  }) => emit(
    eventType: 'salon_viewed',
    targetType: 'salon',
    targetId: businessId,
    metadata: {
      if (context != null) 'context': context,
      if (city != null) 'city': city,
    },
  );

  void searchPerformed({
    String? serviceType,
    String? category,
    int? resultCount,
    String? city,
  }) => emit(
    eventType: 'search_performed',
    targetType: 'service',
    targetId: serviceType,
    metadata: {
      if (category != null) 'category': category,
      if (resultCount != null) 'result_count': resultCount,
      if (city != null) 'city': city,
    },
  );

  void paymentCompleted({
    required String bookingId,
    required double amount,
    required String paymentMethod,
  }) => emit(
    eventType: 'payment_completed',
    targetType: 'booking',
    targetId: bookingId,
    metadata: {'amount': amount, 'payment_method': paymentMethod},
  );

  void productPurchased({
    required String orderId,
    required String productId,
    required double amount,
  }) => emit(
    eventType: 'product_purchased',
    targetType: 'product',
    targetId: productId,
    metadata: {'order_id': orderId, 'amount': amount},
  );
}
