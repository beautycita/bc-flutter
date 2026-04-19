/// Full-profile aggregator for the admin user-detail view.
///
/// Hits `admin_get_user_full_profile(uuid)` (migration
/// 20260419000003_admin_user_full_profile.sql) and keeps the raw jsonb
/// as a typed holder so screens can navigate without fishing through
/// `Map<String, dynamic>` at call sites.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Typed holder ──────────────────────────────────────────────────────────────

@immutable
class AdminUserFullProfile {
  /// Everything the RPC returns, untouched. Use the getters below for
  /// common sections; fall back to this map for anything niche.
  final Map<String, dynamic> raw;

  const AdminUserFullProfile(this.raw);

  // Quick section accessors. All return non-null Maps (RPC guarantees
  // `'{}'::jsonb` COALESCE for missing sections).

  Map<String, dynamic> get profile =>
      (raw['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get auth =>
      (raw['auth'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> get businesses =>
      ((raw['business'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
  Map<String, dynamic> get saldo =>
      (raw['saldo'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get appointments =>
      (raw['appointments'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get orders =>
      (raw['orders'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get loyalty =>
      (raw['loyalty'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get giftCards =>
      (raw['gift_cards'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get disputes =>
      (raw['disputes'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get reviews =>
      (raw['reviews'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get chat =>
      (raw['chat'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get media =>
      (raw['media'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get invites =>
      (raw['invites'] as Map?)?.cast<String, dynamic>() ?? const {};

  Map<String, dynamic> get intelligence =>
      (raw['intelligence'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get traits =>
      (intelligence['traits'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get behaviorSummary =>
      (intelligence['summary'] as Map?)?.cast<String, dynamic>() ?? const {};

  List<Map<String, dynamic>> get adminNotes =>
      ((raw['admin_notes'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  /// Convenience: the 8 trait scores in a canonical order. Unknown traits
  /// (if schema drifts and adds a 9th) go at the end.
  List<MapEntry<String, TraitScore>> get orderedTraits {
    const canonical = [
      'churn_risk',
      'spend_velocity',
      'consistency',
      'initiative',
      'cancellation_rate',
      'payment_reliability',
      'referral_impact',
      'geographic_spread',
    ];
    final out = <MapEntry<String, TraitScore>>[];
    for (final key in canonical) {
      final m = traits[key];
      if (m is Map) {
        out.add(MapEntry(key, TraitScore.fromJson(m.cast<String, dynamic>())));
      }
    }
    for (final entry in traits.entries) {
      if (!canonical.contains(entry.key) && entry.value is Map) {
        out.add(MapEntry(
          entry.key,
          TraitScore.fromJson((entry.value as Map).cast<String, dynamic>()),
        ));
      }
    }
    return out;
  }
}

@immutable
class TraitScore {
  final double score;
  final dynamic rawValue;
  final DateTime? computedAt;

  const TraitScore({
    required this.score,
    required this.rawValue,
    required this.computedAt,
  });

  factory TraitScore.fromJson(Map<String, dynamic> json) => TraitScore(
        score: (json['score'] as num?)?.toDouble() ?? 0,
        rawValue: json['raw_value'],
        computedAt: DateTime.tryParse(json['computed_at'] as String? ?? ''),
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Keyed by user id. Refetches whenever the key changes. Invalidate
/// manually after admin actions that mutate state (role change, saldo
/// edit, note added) to force a re-fetch.
final userFullProfileProvider =
    FutureProvider.family<AdminUserFullProfile, String>((ref, userId) async {
  if (!BCSupabase.isInitialized) {
    throw StateError('Supabase not initialized');
  }
  final result = await BCSupabase.client
      .rpc('admin_get_user_full_profile', params: {'p_user_id': userId});
  if (result is! Map) {
    throw StateError('admin_get_user_full_profile returned ${result.runtimeType}');
  }
  return AdminUserFullProfile(result.cast<String, dynamic>());
});
