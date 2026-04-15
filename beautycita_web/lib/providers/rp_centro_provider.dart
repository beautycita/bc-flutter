import 'package:beautycita_core/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Checklist Constants ─────────────────────────────────────────────────────

/// 7 required checklist items for salon onboarding.
const kRpChecklistRequired = [
  'datos_negocio',
  'servicios',
  'staff',
  'horario_semanal',
  'rfc',
  'stripe_express',
  'info_dispersion',
];

/// 5 optional checklist items.
const kRpChecklistOptional = [
  'instagram',
  'portfolio',
  'fotos_antes_despues',
  'calendario_sync',
  'licencia',
];

/// Human-readable labels for each checklist key.
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

// ── Models ───────────────────────────────────────────────────────────────────

@immutable
class ChecklistItem {
  final String id;
  final String discoveredSalonId;
  final String rpUserId;
  final String itemKey;
  final DateTime? checkedAt;
  final String? notes;

  const ChecklistItem({
    required this.id,
    required this.discoveredSalonId,
    required this.rpUserId,
    required this.itemKey,
    this.checkedAt,
    this.notes,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String? ?? '',
      discoveredSalonId: json['discovered_salon_id'] as String? ?? '',
      rpUserId: json['rp_user_id'] as String? ?? '',
      itemKey: json['item_key'] as String? ?? '',
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  /// Whether this item is part of the required set.
  bool get isRequired => kRpChecklistRequired.contains(itemKey);

  /// Human-readable label for this item.
  String get label => kRpChecklistLabels[itemKey] ?? itemKey;
}

@immutable
class RpMeeting {
  final String id;
  final String discoveredSalonId;
  final String rpUserId;
  final DateTime proposedAt;
  final DateTime? salonProposedAt;
  final DateTime? confirmedAt;
  final String status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RpMeeting({
    required this.id,
    required this.discoveredSalonId,
    required this.rpUserId,
    required this.proposedAt,
    this.salonProposedAt,
    this.confirmedAt,
    required this.status,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory RpMeeting.fromJson(Map<String, dynamic> json) {
    return RpMeeting(
      id: json['id'] as String? ?? '',
      discoveredSalonId: json['discovered_salon_id'] as String? ?? '',
      rpUserId: json['rp_user_id'] as String? ?? '',
      proposedAt:
          DateTime.tryParse(json['proposed_at'] as String? ?? '') ??
              DateTime.now(),
      salonProposedAt: json['salon_proposed_at'] != null
          ? DateTime.tryParse(json['salon_proposed_at'] as String)
          : null,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Fetches all checklist items for a salon.
final rpChecklistProvider =
    FutureProvider.family<List<ChecklistItem>, String>((ref, salonId) async {
  if (!BCSupabase.isInitialized) return [];

  final res = await BCSupabase.client
      .from(BCTables.rpChecklist)
      .select()
      .eq('discovered_salon_id', salonId)
      .order('created_at');

  return (res as List)
      .cast<Map<String, dynamic>>()
      .map(ChecklistItem.fromJson)
      .toList();
});

/// Computed progress: how many required items are checked vs total required.
final rpChecklistProgressProvider =
    Provider.family<({int required, int total}), String>((ref, salonId) {
  final checklist = ref.watch(rpChecklistProvider(salonId));
  final items = checklist.valueOrNull ?? [];

  final checkedRequired = items
      .where((item) =>
          kRpChecklistRequired.contains(item.itemKey) &&
          item.checkedAt != null)
      .length;

  return (required: checkedRequired, total: kRpChecklistRequired.length);
});

/// Next upcoming meeting for a salon.
final rpNextMeetingProvider =
    FutureProvider.family<RpMeeting?, String>((ref, salonId) async {
  if (!BCSupabase.isInitialized) return null;

  final res = await BCSupabase.client
      .from(BCTables.rpMeetings)
      .select()
      .eq('discovered_salon_id', salonId)
      .inFilter('status', ['pending', 'confirmed', 'rescheduled'])
      .gte('proposed_at', DateTime.now().toUtc().toIso8601String())
      .order('proposed_at')
      .limit(1)
      .maybeSingle();

  if (res == null) return null;
  return RpMeeting.fromJson(res);
});

/// All meetings for a salon, newest first.
final rpMeetingsProvider =
    FutureProvider.family<List<RpMeeting>, String>((ref, salonId) async {
  if (!BCSupabase.isInitialized) return [];

  final res = await BCSupabase.client
      .from(BCTables.rpMeetings)
      .select()
      .eq('discovered_salon_id', salonId)
      .order('proposed_at', ascending: false);

  return (res as List)
      .cast<Map<String, dynamic>>()
      .map(RpMeeting.fromJson)
      .toList();
});

// ── Service Functions ────────────────────────────────────────────────────────

/// Toggle a checklist item on/off. Upserts when checked, deletes when unchecked.
Future<void> rpToggleChecklistItem({
  required String salonId,
  required String itemKey,
  required bool checked,
  String? notes,
}) async {
  final userId = BCSupabase.client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  if (checked) {
    await BCSupabase.client.from(BCTables.rpChecklist).upsert(
      {
        'discovered_salon_id': salonId,
        'rp_user_id': userId,
        'item_key': itemKey,
        'checked_at': DateTime.now().toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
      },
      onConflict: 'discovered_salon_id,item_key',
    );
  } else {
    await BCSupabase.client
        .from(BCTables.rpChecklist)
        .delete()
        .eq('discovered_salon_id', salonId)
        .eq('item_key', itemKey);
  }
}

/// Create a new meeting proposal.
Future<String> rpCreateMeeting({
  required String salonId,
  required DateTime proposedAt,
  String? note,
}) async {
  final userId = BCSupabase.client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  final res = await BCSupabase.client.from(BCTables.rpMeetings).insert({
    'discovered_salon_id': salonId,
    'rp_user_id': userId,
    'proposed_at': proposedAt.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  }).select('id').single();

  return res['id'] as String;
}

/// Update meeting status (confirmed, rescheduled, cancelled, completed).
Future<void> rpUpdateMeetingStatus({
  required String meetingId,
  required String status,
  DateTime? salonProposedAt,
}) async {
  await BCSupabase.client.from(BCTables.rpMeetings).update({
    'status': status,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    if (status == 'confirmed')
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
    if (salonProposedAt != null)
      'salon_proposed_at': salonProposedAt.toUtc().toIso8601String(),
  }).eq('id', meetingId);
}

/// Returns the active assignment ID for a salon, or null if none.
Future<String?> getActiveAssignmentId(String salonId) async {
  final res = await BCSupabase.client
      .from(BCTables.rpAssignments)
      .select('id')
      .eq('discovered_salon_id', salonId)
      .isFilter('unassigned_at', null)
      .maybeSingle();

  return res?['id'] as String?;
}

/// Fetches the assigned RP user's name for a salon, given the RP user ID.
final rpAssignmentInfoProvider =
    FutureProvider.family<String?, String?>((ref, rpUserId) async {
  if (rpUserId == null || !BCSupabase.isInitialized) return null;

  final res = await BCSupabase.client
      .from(BCTables.profiles)
      .select('full_name, username')
      .eq('id', rpUserId)
      .maybeSingle();

  if (res == null) return null;
  return (res['full_name'] as String?) ??
      (res['username'] as String?) ??
      'RP desconocido';
});

/// Close the RP process for a salon — updates assignment and salon status.
Future<void> rpCloseProcess({
  required String salonId,
  required String assignmentId,
  required String outcome, // 'completed' or 'not_converted'
  String? reason, // required when not_converted
}) async {
  final client = BCSupabase.client;

  // Close the assignment
  await client.from(BCTables.rpAssignments).update({
    'closed_at': DateTime.now().toUtc().toIso8601String(),
    'close_outcome': outcome,
    if (reason != null) 'close_reason': reason,
  }).eq('id', assignmentId);

  if (outcome == 'not_converted') {
    // Unassign: clear RP, reset status
    await client.from(BCTables.discoveredSalons).update({
      'assigned_rp_id': null,
      'rp_status': 'unassigned',
    }).eq('id', salonId);
  } else {
    // Mark converted
    await client.from(BCTables.discoveredSalons).update({
      'rp_status': 'converted',
    }).eq('id', salonId);
  }
}
