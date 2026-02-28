import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Pipeline stages (match DB status constraint) ────────────────────────────

/// Pipeline stages for outreach — map to `status` column in `discovered_salons`.
enum OutreachStage {
  discovered,
  selected,
  outreachSent,
  registered,
  declined,
  unreachable;

  String get dbValue => switch (this) {
        discovered => 'discovered',
        selected => 'selected',
        outreachSent => 'outreach_sent',
        registered => 'registered',
        declined => 'declined',
        unreachable => 'unreachable',
      };

  String get label => switch (this) {
        discovered => 'Descubiertos',
        selected => 'Seleccionados',
        outreachSent => 'Contactados',
        registered => 'Registrados',
        declined => 'Rechazados',
        unreachable => 'No alcanzables',
      };

  /// The stages that appear as kanban columns (active pipeline).
  static const kanbanStages = [
    selected,
    outreachSent,
    registered,
    declined,
    unreachable,
  ];
}

// ── Data classes ──────────────────────────────────────────────────────────────

/// A discovered salon in the outreach pipeline.
@immutable
class DiscoveredSalon {
  final String id;
  final String name;
  final String city;
  final String? state;
  final String country;
  final String phone;
  final bool hasWhatsApp;
  final OutreachStage stage;
  final DateTime? lastOutreachAt;
  final int outreachCount;
  final String? source;
  final String? address;
  final double? ratingAverage;
  final int? ratingCount;
  final String? categories;
  final String? website;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? featureImageUrl;
  final DateTime createdAt;

  const DiscoveredSalon({
    required this.id,
    required this.name,
    required this.city,
    this.state,
    required this.country,
    required this.phone,
    required this.hasWhatsApp,
    required this.stage,
    this.lastOutreachAt,
    this.outreachCount = 0,
    this.source,
    this.address,
    this.ratingAverage,
    this.ratingCount,
    this.categories,
    this.website,
    this.facebookUrl,
    this.instagramUrl,
    this.featureImageUrl,
    required this.createdAt,
  });

  static OutreachStage _parseStage(String? s) => switch (s) {
        'selected' => OutreachStage.selected,
        'outreach_sent' => OutreachStage.outreachSent,
        'registered' => OutreachStage.registered,
        'declined' => OutreachStage.declined,
        'unreachable' => OutreachStage.unreachable,
        _ => OutreachStage.discovered,
      };

  static DiscoveredSalon fromMap(Map<String, dynamic> row) {
    return DiscoveredSalon(
      id: row['id']?.toString() ?? '',
      name: row['business_name'] as String? ?? 'Sin nombre',
      city: row['location_city'] as String? ?? '',
      state: row['location_state'] as String?,
      country: row['country'] as String? ?? 'MX',
      phone: row['phone'] as String? ?? '',
      hasWhatsApp: row['whatsapp_verified'] == true,
      stage: _parseStage(row['status'] as String?),
      lastOutreachAt:
          DateTime.tryParse(row['last_outreach_at'] as String? ?? ''),
      outreachCount: row['outreach_count'] as int? ?? 0,
      source: row['source'] as String?,
      address: row['location_address'] as String?,
      ratingAverage: (row['rating_average'] as num?)?.toDouble(),
      ratingCount: row['rating_count'] as int?,
      categories: row['categories'] as String?,
      website: row['website'] as String?,
      facebookUrl: row['facebook_url'] as String?,
      instagramUrl: row['instagram_url'] as String?,
      featureImageUrl: row['feature_image_url'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// An outreach log entry.
@immutable
class OutreachLogEntry {
  final String id;
  final String salonId;
  final String channel; // 'whatsapp', 'sms', 'email'
  final String? recipientPhone;
  final String? messageText;
  final DateTime sentAt;

  const OutreachLogEntry({
    required this.id,
    required this.salonId,
    required this.channel,
    this.recipientPhone,
    this.messageText,
    required this.sentAt,
  });

  static OutreachLogEntry fromMap(Map<String, dynamic> row) {
    return OutreachLogEntry(
      id: row['id']?.toString() ?? '',
      salonId: row['discovered_salon_id']?.toString() ?? '',
      channel: row['channel'] as String? ?? '',
      recipientPhone: row['recipient_phone'] as String?,
      messageText: row['message_text'] as String?,
      sentAt: DateTime.tryParse(row['sent_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Pipeline salons — only those that have moved past 'discovered' status.
/// The kanban doesn't show 28k+ discovered salons; that's what the Salons page
/// is for. This loads only the active pipeline (selected, outreach_sent, etc.).
final pipelineSalonsProvider =
    FutureProvider<List<DiscoveredSalon>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    // Explicit in_ is more index-friendly than neq('discovered') on 28k rows.
    final pipelineStatuses = OutreachStage.kanbanStages
        .map((s) => s.dbValue)
        .toList();

    final data = await BCSupabase.client
        .from(BCTables.discoveredSalons)
        .select(
          'id, business_name, location_city, location_state, country, phone, '
          'whatsapp_verified, status, last_outreach_at, outreach_count, source, '
          'location_address, rating_average, rating_count, categories, website, '
          'facebook_url, instagram_url, feature_image_url, created_at',
        )
        .inFilter('status', pipelineStatuses)
        .order('last_outreach_at', ascending: false)
        .limit(500)
        .timeout(const Duration(seconds: 10));

    return data.map((row) => DiscoveredSalon.fromMap(row)).toList();
  } catch (e) {
    debugPrint('Pipeline salons error: $e');
    return [];
  }
});

/// Count of discovered (not-yet-in-pipeline) salons, by country.
final discoveredCountsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  if (!BCSupabase.isInitialized) return {};

  try {
    final client = BCSupabase.client;

    // Run counts in parallel with timeouts.
    final results = await Future.wait([
      client
          .from(BCTables.discoveredSalons)
          .select('id')
          .eq('status', 'discovered')
          .limit(1)
          .count()
          .timeout(const Duration(seconds: 10)),
      client
          .from(BCTables.discoveredSalons)
          .select('id')
          .eq('status', 'discovered')
          .eq('country', 'MX')
          .limit(1)
          .count()
          .timeout(const Duration(seconds: 10)),
      client
          .from(BCTables.discoveredSalons)
          .select('id')
          .eq('status', 'discovered')
          .eq('country', 'US')
          .limit(1)
          .count()
          .timeout(const Duration(seconds: 10)),
    ]);

    return {
      'total': results[0].count,
      'MX': results[1].count,
      'US': results[2].count,
    };
  } catch (e) {
    debugPrint('Discovered counts error: $e');
    return {'total': 0, 'MX': 0, 'US': 0};
  }
});

/// Stage counts for the kanban header (excluding discovered — shown separately).
final outreachStageCounts =
    Provider<Map<OutreachStage, int>>((ref) {
  final salonsAsync = ref.watch(pipelineSalonsProvider);
  return salonsAsync.when(
    loading: () => {for (final s in OutreachStage.kanbanStages) s: 0},
    error: (_, __) => {for (final s in OutreachStage.kanbanStages) s: 0},
    data: (salons) {
      final counts = {for (final s in OutreachStage.kanbanStages) s: 0};
      for (final salon in salons) {
        if (counts.containsKey(salon.stage)) {
          counts[salon.stage] = (counts[salon.stage] ?? 0) + 1;
        }
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
        .eq('discovered_salon_id', salonId)
        .order('sent_at', ascending: false);

    return data.map((row) => OutreachLogEntry.fromMap(row)).toList();
  } catch (e) {
    debugPrint('Outreach log error: $e');
    return [];
  }
});
