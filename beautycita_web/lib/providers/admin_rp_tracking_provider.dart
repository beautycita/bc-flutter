import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

@immutable
class RpPerformance {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int assigned;
  final int converted;
  final int daysActive;

  const RpPerformance({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.assigned,
    required this.converted,
    required this.daysActive,
  });

  double get conversionRate =>
      assigned == 0 ? 0.0 : converted / assigned;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final adminRpTrackingProvider =
    FutureProvider<List<RpPerformance>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  final client = BCSupabase.client;

  // Fetch all RP profiles
  final profiles = await client
      .from(BCTables.profiles)
      .select('id, full_name, avatar_url, created_at')
      .eq('role', 'rp');

  if ((profiles as List).isEmpty) return [];

  final rpIds = profiles.map((p) => p['id'] as String).toList();

  // Fetch assignment counts per RP
  final assignments = await client
      .from(BCTables.rpAssignments)
      .select('rp_user_id, status')
      .inFilter('rp_user_id', rpIds);

  // Aggregate per RP
  final Map<String, ({int assigned, int converted})> counts = {};
  for (final a in assignments as List) {
    final rpId = a['rp_user_id'] as String;
    final status = a['status'] as String? ?? '';
    final cur = counts[rpId] ?? (assigned: 0, converted: 0);
    final isConverted = status == 'completed' || status == 'converted';
    counts[rpId] = (
      assigned: cur.assigned + 1,
      converted: cur.converted + (isConverted ? 1 : 0),
    );
  }

  final now = DateTime.now();

  return profiles.map<RpPerformance>((p) {
    final id = p['id'] as String;
    final createdAt = DateTime.tryParse(p['created_at'] as String? ?? '') ??
        now;
    final daysActive = now.difference(createdAt).inDays.clamp(0, 9999);
    final c = counts[id] ?? (assigned: 0, converted: 0);

    return RpPerformance(
      userId: id,
      fullName: (p['full_name'] as String?) ?? 'Sin nombre',
      avatarUrl: p['avatar_url'] as String?,
      assigned: c.assigned,
      converted: c.converted,
      daysActive: daysActive,
    );
  }).toList();
});

// ── Sort state ────────────────────────────────────────────────────────────────

@immutable
class RpSort {
  final String column;
  final bool ascending;

  const RpSort({this.column = 'converted', this.ascending = false});

  RpSort copyWith({String? column, bool? ascending}) => RpSort(
        column: column ?? this.column,
        ascending: ascending ?? this.ascending,
      );
}

final rpSortProvider = StateProvider<RpSort>((ref) => const RpSort());
