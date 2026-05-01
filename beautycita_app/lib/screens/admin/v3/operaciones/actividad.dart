// Operaciones → Actividad
//
// Live activity feed sourced from audit_log (Phase 0 mig 002). Most recent
// 50 mutations across all 9 trigger-attached tables. Each row shows actor,
// action, target — matches the audit-trail expectation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_v3_queue_provider.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class OperacionesActividad extends ConsumerWidget {
  const OperacionesActividad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRows = ref.watch(adminRecentAuditProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminRecentAuditProvider),
      child: asyncRows.when(
        loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
        error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin actividad reciente'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
            itemCount: rows.length,
            itemBuilder: (ctx, i) => _Row(row: rows[i]),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final Map<String, dynamic> row;

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final ago = DateTime.now().difference(dt);
      if (ago.inMinutes < 60) return 'hace ${ago.inMinutes}m';
      if (ago.inHours < 24) return 'hace ${ago.inHours}h';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
    } catch (_) {
      return '';
    }
  }

  IconData _icon(String? action) => switch (action) {
        'INSERT' => Icons.add_circle_outline,
        'UPDATE' => Icons.edit_outlined,
        'DELETE' => Icons.delete_outline,
        _ => Icons.history,
      };

  Color _color(BuildContext c, String? action) => switch (action) {
        'INSERT' => AdminV2Tokens.success(c),
        'DELETE' => AdminV2Tokens.destructive(c),
        _ => Theme.of(c).colorScheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final action = row['action'] as String?;
    final table = row['target_table'] as String? ?? '?';
    final actorRole = row['actor_role'] as String? ?? '?';
    final occurred = _fmtTime(row['occurred_at'] as String?);
    final color = _color(context, action);
    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: AdminV2Tokens.spacingMD),
            child: Icon(_icon(action), color: color, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${action ?? ''}  $table',
                  style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('por $actorRole', style: AdminV2Tokens.muted(context)),
              ],
            ),
          ),
          Text(occurred, style: AdminV2Tokens.muted(context)),
        ],
      ),
    );
  }
}
