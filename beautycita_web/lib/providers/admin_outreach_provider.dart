import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// Pipeline stages for outreach.
enum OutreachStage {
  nuevo,
  contactado,
  respondido,
  interesado,
  onboarded;

  String get label => switch (this) {
        nuevo => 'Nuevos',
        contactado => 'Contactados',
        respondido => 'Respondidos',
        interesado => 'Interesados',
        onboarded => 'Onboarded',
      };
}

/// A discovered salon in the outreach pipeline.
@immutable
class DiscoveredSalon {
  final String id;
  final String name;
  final String city;
  final String phone;
  final bool hasWhatsApp;
  final OutreachStage stage;
  final DateTime? lastContactDate;
  final String? source;
  final String? address;
  final String? notes;

  const DiscoveredSalon({
    required this.id,
    required this.name,
    required this.city,
    required this.phone,
    required this.hasWhatsApp,
    required this.stage,
    this.lastContactDate,
    this.source,
    this.address,
    this.notes,
  });

  static OutreachStage _parseStage(String? s) => switch (s) {
        'contactado' => OutreachStage.contactado,
        'respondido' => OutreachStage.respondido,
        'interesado' => OutreachStage.interesado,
        'onboarded' => OutreachStage.onboarded,
        _ => OutreachStage.nuevo,
      };

  static DiscoveredSalon fromMap(Map<String, dynamic> row) {
    return DiscoveredSalon(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      city: row['city'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      hasWhatsApp: row['has_whatsapp'] as bool? ?? false,
      stage: _parseStage(row['stage'] as String?),
      lastContactDate: row['last_contact_date'] != null
          ? DateTime.tryParse(row['last_contact_date'] as String)
          : null,
      source: row['source'] as String?,
      address: row['address'] as String?,
      notes: row['notes'] as String?,
    );
  }
}

/// An outreach log entry.
@immutable
class OutreachLogEntry {
  final String id;
  final String salonId;
  final String action;
  final String? notes;
  final DateTime createdAt;

  const OutreachLogEntry({
    required this.id,
    required this.salonId,
    required this.action,
    this.notes,
    required this.createdAt,
  });

  static OutreachLogEntry fromMap(Map<String, dynamic> row) {
    return OutreachLogEntry(
      id: row['id'] as String? ?? '',
      salonId: row['salon_id'] as String? ?? '',
      action: row['action'] as String? ?? '',
      notes: row['notes'] as String?,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// All discovered salons.
final discoveredSalonsProvider =
    FutureProvider<List<DiscoveredSalon>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from('discovered_salons')
        .select()
        .order('created_at', ascending: false);

    return data.map((row) => DiscoveredSalon.fromMap(row)).toList();
  } catch (e) {
    debugPrint('Discovered salons error: $e');
    return [];
  }
});

/// Stage counts for the kanban header.
final outreachStageCounts =
    Provider<Map<OutreachStage, int>>((ref) {
  final salonsAsync = ref.watch(discoveredSalonsProvider);
  return salonsAsync.when(
    loading: () => {for (final s in OutreachStage.values) s: 0},
    error: (_, __) => {for (final s in OutreachStage.values) s: 0},
    data: (salons) {
      final counts = {for (final s in OutreachStage.values) s: 0};
      for (final salon in salons) {
        counts[salon.stage] = (counts[salon.stage] ?? 0) + 1;
      }
      return counts;
    },
  );
});

/// Outreach log for a specific salon.
final salonOutreachLogProvider =
    FutureProvider.family<List<OutreachLogEntry>, String>(
        (ref, salonId) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from('salon_outreach_log')
        .select()
        .eq('salon_id', salonId)
        .order('created_at', ascending: false);

    return data.map((row) => OutreachLogEntry.fromMap(row)).toList();
  } catch (e) {
    debugPrint('Outreach log error: $e');
    return [];
  }
});
