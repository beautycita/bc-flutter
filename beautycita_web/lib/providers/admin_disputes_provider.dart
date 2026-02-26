import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class Dispute {
  final String id;
  final String clientId;
  final String clientName;
  final String salonId;
  final String salonName;
  final String? bookingRef;
  final String type; // 'service_quality', 'no_show', 'overcharge', 'other'
  final double amount;
  final String status; // 'open', 'reviewing', 'resolved', 'rejected'
  final String description;
  final String? evidence; // URL or text
  final String? resolutionNotes;
  final String? resolutionDecision; // 'refund_full', 'refund_partial', 'reject'
  final double? refundAmount;
  final DateTime filedAt;
  final DateTime? resolvedAt;
  final List<DisputeTimelineEntry> timeline;

  const Dispute({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.salonId,
    required this.salonName,
    this.bookingRef,
    required this.type,
    required this.amount,
    required this.status,
    required this.description,
    this.evidence,
    this.resolutionNotes,
    this.resolutionDecision,
    this.refundAmount,
    required this.filedAt,
    this.resolvedAt,
    this.timeline = const [],
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    // Parse timeline if present
    final timelineData = json['timeline'] as List<dynamic>? ?? [];
    final timeline = timelineData
        .map((e) => DisputeTimelineEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return Dispute(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      clientName: json['client_name'] as String? ??
          (json['profiles'] != null
              ? json['profiles']['display_name'] as String? ?? 'Usuario'
              : 'Usuario'),
      salonId: json['salon_id'] as String? ?? '',
      salonName: json['salon_name'] as String? ??
          (json['businesses'] != null
              ? json['businesses']['name'] as String? ?? 'Salon'
              : 'Salon'),
      bookingRef: json['booking_ref'] as String? ??
          json['appointment_id'] as String?,
      type: json['type'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'open',
      description: json['description'] as String? ?? '',
      evidence: json['evidence'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      resolutionDecision: json['resolution_decision'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      filedAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      timeline: timeline,
    );
  }

  String get typeLabel => switch (type) {
        'service_quality' => 'Calidad',
        'no_show' => 'No show',
        'overcharge' => 'Cobro excesivo',
        'other' => 'Otro',
        _ => type,
      };

  String get statusLabel => switch (status) {
        'open' => 'Abierta',
        'reviewing' => 'En revision',
        'resolved' => 'Resuelta',
        'rejected' => 'Rechazada',
        _ => status,
      };
}

@immutable
class DisputeTimelineEntry {
  final String status;
  final String? note;
  final DateTime timestamp;
  final String? actorName;

  const DisputeTimelineEntry({
    required this.status,
    this.note,
    required this.timestamp,
    this.actorName,
  });

  factory DisputeTimelineEntry.fromJson(Map<String, dynamic> json) {
    return DisputeTimelineEntry(
      status: json['status'] as String? ?? '',
      note: json['note'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      actorName: json['actor_name'] as String?,
    );
  }
}

@immutable
class DisputeFilters {
  final String? status;
  final String? type;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String searchQuery;

  const DisputeFilters({
    this.status,
    this.type,
    this.dateFrom,
    this.dateTo,
    this.searchQuery = '',
  });

  DisputeFilters copyWith({
    String? Function()? status,
    String? Function()? type,
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    String? searchQuery,
  }) {
    return DisputeFilters(
      status: status != null ? status() : this.status,
      type: type != null ? type() : this.type,
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      status != null || type != null || dateFrom != null || dateTo != null;

  static const empty = DisputeFilters();
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Filter state for disputes.
final disputeFiltersProvider =
    StateProvider<DisputeFilters>((ref) => DisputeFilters.empty);

/// Selected dispute for the detail panel.
final selectedDisputeProvider = StateProvider<Dispute?>((ref) => null);

/// Loads disputes with current filters applied.
final disputesProvider = FutureProvider<List<Dispute>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  final filters = ref.watch(disputeFiltersProvider);

  try {
    var query = BCSupabase.client
        .from(BCTables.disputes)
        .select('*, profiles!client_id(display_name), businesses!salon_id(name)');

    if (filters.status != null) {
      query = query.eq('status', filters.status!);
    }
    if (filters.type != null) {
      query = query.eq('type', filters.type!);
    }
    if (filters.dateFrom != null) {
      query = query.gte('created_at', filters.dateFrom!.toIso8601String());
    }
    if (filters.dateTo != null) {
      query = query.lte('created_at', filters.dateTo!.toIso8601String());
    }

    final data = await query.order('created_at', ascending: false);

    var disputes = (data as List).map((row) {
      // Extract joined data
      final profileData = row['profiles'] as Map<String, dynamic>?;
      final businessData = row['businesses'] as Map<String, dynamic>?;
      final json = Map<String, dynamic>.from(row);
      if (profileData != null) {
        json['client_name'] = profileData['display_name'] ?? 'Usuario';
      }
      if (businessData != null) {
        json['salon_name'] = businessData['name'] ?? 'Salon';
      }
      return Dispute.fromJson(json);
    }).toList();

    // Client-side text search
    if (filters.searchQuery.isNotEmpty) {
      final q = filters.searchQuery.toLowerCase();
      disputes = disputes.where((d) {
        return d.clientName.toLowerCase().contains(q) ||
            d.salonName.toLowerCase().contains(q) ||
            d.id.toLowerCase().contains(q) ||
            (d.bookingRef?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return disputes;
  } catch (e) {
    debugPrint('Disputes error: $e');
    return [];
  }
});
