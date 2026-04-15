import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Checks for the most recent completed appointment that has no review yet.
/// Returns null if nothing to review, or a map with appointment + business info.
final unreviewedAppointmentProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  if (!SupabaseClientService.isInitialized) return null;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return null;

  try {
    // Find completed appointments that ended > 2 hours ago with no review
    final twoHoursAgo =
        DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String();

    final rows = await SupabaseClientService.client
        .from(BCTables.appointments)
        .select('id, business_id, ends_at, businesses(name)')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .lt('ends_at', twoHoursAgo)
        .order('ends_at', ascending: false)
        .limit(5);

    if ((rows as List).isEmpty) return null;

    // For each, check if a review already exists
    for (final appt in rows) {
      final appointmentId = appt['id'] as String;
      final existing = await SupabaseClientService.client
          .from(BCTables.reviews)
          .select('id')
          .eq('appointment_id', appointmentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // This appointment has no review — return it
        return Map<String, dynamic>.from(appt);
      }
    }
    return null;
  } catch (_) {
    return null;
  }
});

/// Submit a review for an appointment.
Future<void> submitReview({
  required String appointmentId,
  required String businessId,
  required int rating,
  String? comment,
}) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) throw Exception('User not authenticated');

  await SupabaseClientService.client.from(BCTables.reviews).insert({
    'user_id': userId,
    'business_id': businessId,
    'appointment_id': appointmentId,
    'rating': rating,
    if (comment != null && comment.trim().isNotEmpty)
      'comment': comment.trim(),
  });
}
