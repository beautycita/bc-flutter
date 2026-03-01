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
  final String status; // 'open', 'salon_responded', 'escalated', 'resolved', 'rejected'
  final String description;
  final String? evidence; // URL or text
  final String? resolutionNotes;
  final String? resolutionDecision; // 'refund_full', 'refund_partial', 'reject'
  final double? refundAmount;
  final DateTime filedAt;
  final DateTime? resolvedAt;
  final List<DisputeTimelineEntry> timeline;

  // Salon offer fields
  final String? salonOffer; // 'full_refund', 'partial_refund', 'denied'
  final double? salonOfferAmount;
  final String? salonResponse;
  final DateTime? salonOfferedAt;
  final bool? clientAccepted;
  final DateTime? clientRespondedAt;
  final DateTime? escalatedAt;

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
    this.salonOffer,
    this.salonOfferAmount,
    this.salonResponse,
    this.salonOfferedAt,
    this.clientAccepted,
    this.clientRespondedAt,
    this.escalatedAt,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    // Parse timeline if present
    final timelineData = json['timeline'] as List<dynamic>? ?? [];
    final timeline = timelineData
        .map((e) => DisputeTimelineEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return Dispute(
      id: json['id'] as String,
      clientId: json['user_id'] as String? ?? '',
      clientName: json['client_name'] as String? ??
          (json['profiles'] != null
              ? json['profiles']['full_name'] as String? ??
                  json['profiles']['username'] as String? ??
                  'Usuario'
              : 'Usuario'),
      salonId: json['business_id'] as String? ?? '',
      salonName: json['salon_name'] as String? ??
          (json['businesses'] != null
              ? json['businesses']['name'] as String? ?? 'Salon'
              : 'Salon'),
      bookingRef: json['appointment_id'] as String?,
      type: json['reason'] as String? ?? 'other',
      amount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'open',
      description: json['reason'] as String? ?? '',
      evidence: json['client_evidence'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      resolutionDecision: json['resolution'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      filedAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      timeline: timeline,
      salonOffer: json['salon_offer'] as String?,
      salonOfferAmount: (json['salon_offer_amount'] as num?)?.toDouble(),
      salonResponse: json['salon_response'] as String?,
      salonOfferedAt: json['salon_offered_at'] != null
          ? DateTime.tryParse(json['salon_offered_at'] as String)
          : null,
      clientAccepted: json['client_accepted'] as bool?,
      clientRespondedAt: json['client_responded_at'] != null
          ? DateTime.tryParse(json['client_responded_at'] as String)
          : null,
      escalatedAt: json['escalated_at'] != null
          ? DateTime.tryParse(json['escalated_at'] as String)
          : null,
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
        'salon_responded' => 'Salon respondio',
        'escalated' => 'Escalada',
        'reviewing' => 'En revision',
        'resolved' => 'Resuelta',
        'rejected' => 'Rechazada',
        _ => status,
      };

  String get salonOfferLabel => switch (salonOffer) {
        'full_refund' => 'Reembolso total',
        'partial_refund' => 'Reembolso parcial',
        'denied' => 'Reembolso negado',
        _ => salonOffer ?? '-',
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
        .select('*, profiles!disputes_user_id_profiles_fkey(full_name, username), businesses!disputes_business_id_fkey(name)');

    if (filters.status != null) {
      query = query.eq('status', filters.status!);
    }
    if (filters.type != null) {
      query = query.eq('reason', filters.type!);
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
        json['client_name'] = profileData['full_name'] ??
            profileData['username'] ??
            'Usuario';
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
