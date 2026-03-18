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
        .eq('discovered_salon_id', salonId)
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
      .eq('discovered_salon_id', salonId)
      .isFilter('unassigned_at', null)
      .maybeSingle();

  return response?['id'] as String?;
}

// ---------------------------------------------------------------------------
// RP Centro de Comunicaciones — checklist, meetings, chat, close-out
// ---------------------------------------------------------------------------

// ── Checklist ──

/// All 12 checklist item keys (7 required + 5 optional)
const kRpChecklistRequired = [
  'datos_negocio',
  'servicios',
  'staff',
  'horario_semanal',
  'rfc',
  'stripe_express',
  'info_dispersion',
];

const kRpChecklistOptional = [
  'instagram',
  'portfolio',
  'fotos_antes_despues',
  'calendario_sync',
  'licencia',
];

const kRpChecklistLabels = {
  'datos_negocio': 'Datos del negocio',
  'servicios': 'Servicios configurados',
  'staff': 'Staff registrado',
  'horario_semanal': 'Horario semanal',
  'rfc': 'RFC registrado',
  'stripe_express': 'Stripe Express completado',
  'info_dispersion': 'Información de dispersión',
  'instagram': 'Instagram importado',
  'portfolio': 'Portfolio curado',
  'fotos_antes_despues': 'Fotos antes/después',
  'calendario_sync': 'Calendario sincronizado',
  'licencia': 'Licencia de funcionamiento',
};

final rpChecklistProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, salonId) async {
    final sb = SupabaseClientService.client;
    final res = await sb
        .from('rp_checklist')
        .select()
        .eq('discovered_salon_id', salonId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  },
);

Future<void> rpToggleChecklistItem({
  required String salonId,
  required String itemKey,
  required bool checked,
  String? notes,
}) async {
  final sb = SupabaseClientService.client;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) throw Exception('Not authenticated');

  if (checked) {
    await sb.from('rp_checklist').upsert({
      'discovered_salon_id': salonId,
      'rp_user_id': userId,
      'item_key': itemKey,
      'checked_at': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
    }, onConflict: 'discovered_salon_id,item_key');
  } else {
    await sb
        .from('rp_checklist')
        .delete()
        .eq('discovered_salon_id', salonId)
        .eq('item_key', itemKey);
  }
}

// ── Meetings ──

final rpNextMeetingProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, salonId) async {
    final sb = SupabaseClientService.client;
    final res = await sb
        .from('rp_meetings')
        .select()
        .eq('discovered_salon_id', salonId)
        .inFilter('status', ['pending', 'confirmed', 'rescheduled'])
        .gte('proposed_at', DateTime.now().toUtc().toIso8601String())
        .order('proposed_at')
        .limit(1)
        .maybeSingle();
    return res;
  },
);

Future<String> rpCreateMeeting({
  required String salonId,
  required DateTime proposedAt,
  String? note,
}) async {
  final sb = SupabaseClientService.client;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) throw Exception('Not authenticated');
  final res = await sb.from('rp_meetings').insert({
    'discovered_salon_id': salonId,
    'rp_user_id': userId,
    'proposed_at': proposedAt.toIso8601String(),
    'note': note,
  }).select('id').single();
  return res['id'] as String;
}

Future<void> rpUpdateMeetingStatus({
  required String meetingId,
  required String status,
  DateTime? salonProposedAt,
}) async {
  final sb = SupabaseClientService.client;
  await sb.from('rp_meetings').update({
    'status': status,
    'updated_at': DateTime.now().toIso8601String(),
    if (status == 'confirmed') 'confirmed_at': DateTime.now().toIso8601String(),
    if (salonProposedAt != null) 'salon_proposed_at': salonProposedAt.toIso8601String(),
  }).eq('id', meetingId);
}

// ── Chat History ──

final rpChatHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String salonId, String? channel})>(
  (ref, params) async {
    final sb = SupabaseClientService.client;
    final res = await sb.functions.invoke('outreach-contact', body: {
      'action': 'get_history',
      'discovered_salon_id': params.salonId,
    });
    if (res.status != 200) return [];
    final data = res.data;
    final history = List<Map<String, dynamic>>.from(data['history'] ?? []);
    if (params.channel != null) {
      return history.where((h) => h['channel'] == params.channel).toList();
    }
    return history;
  },
);

final rpTemplatesProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, channel) async {
    final sb = SupabaseClientService.client;
    final res = await sb.functions.invoke('outreach-contact', body: {
      'action': 'get_templates',
      if (channel != null) 'channel': channel,
    });
    if (res.status != 200) return [];
    return List<Map<String, dynamic>>.from(res.data['templates'] ?? []);
  },
);

// ── Send Message ──

Future<bool> rpSendMessage({
  required String salonId,
  required String channel, // 'whatsapp' or 'email'
  required String message,
  String? subject, // email only
  String? templateId,
}) async {
  final sb = SupabaseClientService.client;
  final currentUser = sb.auth.currentUser;
  if (currentUser == null) throw Exception('Not authenticated');
  final profile = await sb.from('profiles').select('full_name, phone').eq('id', currentUser.id).single();

  final action = channel == 'email' ? 'send_email' : 'send_wa';
  final res = await sb.functions.invoke('outreach-contact', body: {
    'action': action,
    'discovered_salon_id': salonId,
    'message': message,
    if (subject != null) 'subject': subject,
    if (templateId != null) 'template_id': templateId,
    'rp_name': profile['full_name'] ?? 'RP',
    'rp_phone': profile['phone'] ?? '',
  });
  return res.status == 200 && (res.data['sent'] == true || res.data['logged'] == true);
}

// ── Close Process ──

Future<void> rpCloseProcess({
  required String salonId,
  required String assignmentId,
  required String outcome, // 'completed' or 'not_converted'
  String? reason, // required when not_converted
}) async {
  final sb = SupabaseClientService.client;

  // Update assignment
  await sb.from('rp_assignments').update({
    'closed_at': DateTime.now().toIso8601String(),
    'close_outcome': outcome,
    if (reason != null) 'close_reason': reason,
    if (outcome == 'not_converted')
      'unassigned_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', assignmentId);

  if (outcome == 'not_converted') {
    // Unassign: clear RP, reset status
    await sb.from('discovered_salons').update({
      'assigned_rp_id': null,
      'rp_status': 'unassigned',
    }).eq('id', salonId);
  } else {
    // Mark converted
    await sb.from('discovered_salons').update({
      'rp_status': 'converted',
    }).eq('id', salonId);
  }
}
