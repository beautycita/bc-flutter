import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

// ---------------------------------------------------------------------------
// RP (Public Relations) Providers
// ---------------------------------------------------------------------------

/// All discovered_salons assigned to the current RP user.
/// Ordered by rp_status first, then business_name.
final rpAssignedSalonsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseClientService.client
      .from('discovered_salons')
      .select(
        'id, business_name, phone, whatsapp, location_address, location_city, '
        'location_state, latitude, longitude, feature_image_url, rating_average, '
        'rating_count, categories, working_hours, website, facebook_url, '
        'instagram_url, rp_status, assigned_rp_id',
      )
      .eq('assigned_rp_id', userId)
      .order('rp_status')
      .order('business_name');

  return (response as List).cast<Map<String, dynamic>>();
});

/// Visit history for a single salon by the current RP. Limited to 20 most recent.
final rpVisitsForSalonProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, salonId) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseClientService.client
      .from('rp_visits')
      .select()
      .eq('salon_id', salonId)
      .eq('rp_user_id', userId)
      .order('visited_at', ascending: false)
      .limit(20);

  return (response as List).cast<Map<String, dynamic>>();
});

/// Log a visit and update the salon's rp_status accordingly.
Future<void> rpLogVisit({
  required String assignmentId,
  required String salonId,
  required bool verbalContact,
  required bool onboardingComplete,
  int? interestLevel,
  String? notes,
}) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) throw Exception('Not authenticated');

  final client = SupabaseClientService.client;

  // Insert visit record
  await client.from('rp_visits').insert({
    'assignment_id': assignmentId,
    'salon_id': salonId,
    'rp_user_id': userId,
    'verbal_contact': verbalContact,
    'onboarding_complete': onboardingComplete,
    'interest_level': ?interestLevel,
    'notes': ?notes,
  });

  // Update salon rp_status
  final newStatus = onboardingComplete ? 'onboarding_complete' : 'visited';
  await client
      .from('discovered_salons')
      .update({'rp_status': newStatus})
      .eq('id', salonId);
}

// ---------------------------------------------------------------------------
// Admin-facing RP providers
// ---------------------------------------------------------------------------

/// All users with role='rp'. Used by admin for the assignment picker.
final rpUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('profiles')
      .select('id, full_name, username, phone, avatar_url')
      .eq('role', 'rp')
      .order('full_name');

  return (response as List).cast<Map<String, dynamic>>();
});

/// Assign a list of salons to an RP user. Creates rp_assignments rows and
/// updates discovered_salons.assigned_rp_id + rp_status.
Future<void> adminAssignSalonsToRp({
  required List<String> salonIds,
  required String rpUserId,
}) async {
  final adminId = SupabaseClientService.currentUserId;
  if (adminId == null) throw Exception('Not authenticated');

  final client = SupabaseClientService.client;

  for (final salonId in salonIds) {
    // Delete any existing active assignment (hard delete — cleaner than soft delete)
    await client.from('rp_assignments')
        .delete()
        .eq('discovered_salon_id', salonId)
        .isFilter('unassigned_at', null);

    // Create new assignment
    await client.from('rp_assignments').insert({
      'discovered_salon_id': salonId,
      'rp_user_id': rpUserId,
      'assigned_by': adminId,
    });

    await client.from('discovered_salons').update({
      'assigned_rp_id': rpUserId,
      'rp_status': 'assigned',
    }).eq('id', salonId);
  }
}

/// Unassign salons from their current RP. Sets unassigned_at on active
/// assignments and clears discovered_salons.assigned_rp_id.
Future<void> adminUnassignSalons({
  required List<String> salonIds,
}) async {
  final client = SupabaseClientService.client;

  for (final salonId in salonIds) {
    await client
        .from('rp_assignments')
        .update({'unassigned_at': DateTime.now().toUtc().toIso8601String()})
        .eq('salon_id', salonId)
        .isFilter('unassigned_at', null);

    await client.from('discovered_salons').update({
      'assigned_rp_id': null,
      'rp_status': 'unassigned',
    }).eq('id', salonId);
  }
}

/// Returns the active assignment ID for a salon, or null if none.
Future<String?> getActiveAssignmentId(String salonId) async {
  final response = await SupabaseClientService.client
      .from('rp_assignments')
      .select('id')
      .eq('salon_id', salonId)
      .isFilter('unassigned_at', null)
      .maybeSingle();

  return response?['id'] as String?;
}
