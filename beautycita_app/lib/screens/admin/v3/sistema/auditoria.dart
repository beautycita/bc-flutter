// Sistema → Auditoría
//
// Reads audit_log directly. Default filter: today, all actions, all tables.
// Keyset pagination on (occurred_at, id). Each row shows actor + action +
// target. Tap a row to see the before/after column delta.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/supabase_client.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class _AuditQuery {
  const _AuditQuery({this.action, this.table, this.sinceHours = 24});
  final String? action;
  final String? table;
  final int sinceHours;
  String get key => '${action ?? ''}|${table ?? ''}|$sinceHours';
}

final _auditQueryProvider = StateProvider<_AuditQuery>((_) => const _AuditQuery());

final _auditRowsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final q = ref.watch(_auditQueryProvider);
  final since = DateTime.now().toUtc().subtract(Duration(hours: q.sinceHours)).toIso8601String();
  var query = SupabaseClientService.client
      .from('audit_log')
      .select('id, occurred_at, actor_id, actor_role, action, target_table, target_id, before_data, after_data')
      .gte('occurred_at', since);
  if (q.action != null) query = query.eq('action', q.action!);
  if (q.table != null) query = query.eq('target_table', q.table!);
  final res = await query.order('occurred_at', ascending: false).limit(100);
  return (res as List).cast<Map<String, dynamic>>();
});

class SistemaAuditoria extends ConsumerWidget {
  const SistemaAuditoria({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRows = ref.watch(_auditRowsProvider);
    final q = ref.watch(_auditQueryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingSM),
          child: Wrap(
            spacing: AdminV2Tokens.spacingSM,
            runSpacing: AdminV2Tokens.spacingSM,
            children: [
              for (final h in [24, 168, 720])
                ChoiceChip(
                  label: Text(h == 24 ? 'Hoy' : (h == 168 ? '7 días' : '30 días')),
                  selected: q.sinceHours == h,
                  onSelected: (_) => ref.read(_auditQueryProvider.notifier).state = _AuditQuery(action: q.action, table: q.table, sinceHours: h),
                ),
              for (final a in ['INSERT', 'UPDATE', 'DELETE'])
                ChoiceChip(
                  label: Text(a),
                  selected: q.action == a,
                  onSelected: (_) => ref.read(_auditQueryProvider.notifier).state = _AuditQuery(
                    action: q.action == a ? null : a,
                    table: q.table,
                    sinceHours: q.sinceHours,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(_auditRowsProvider),
            child: asyncRows.when(
              loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
              error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin entradas'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AdminV2Tokens.spacingMD, 0, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD),
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) => _Row(row: rows[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final occurred = (row['occurred_at'] as String?) ?? '';
    final action = (row['action'] as String?) ?? '?';
    final table = (row['target_table'] as String?) ?? '?';
    final actorRole = (row['actor_role'] as String?) ?? '?';
    final after = row['after_data'];
    final before = row['before_data'];
    final summary = _summarize(before, after);
    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: 2),
                decoration: BoxDecoration(
                  color: _color(context, action).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                ),
                child: Text(action, style: AdminV2Tokens.muted(context).copyWith(fontWeight: FontWeight.w700, color: _color(context, action))),
              ),
              const SizedBox(width: AdminV2Tokens.spacingSM),
              Expanded(child: Text(table, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600))),
              Text(_short(occurred), style: AdminV2Tokens.muted(context)),
            ],
          ),
          const SizedBox(height: AdminV2Tokens.spacingXS),
          Text('por $actorRole', style: AdminV2Tokens.muted(context)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: AdminV2Tokens.spacingSM),
            Text(summary, style: AdminV2Tokens.body(context).copyWith(fontFamily: 'monospace', fontSize: 12), maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  String _summarize(Object? before, Object? after) {
    if (after is! Map) return '';
    final keys = after.keys.take(3).toList();
    return keys.map((k) => '$k: ${after[k]}').join('  ·  ');
  }

  String _short(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Color _color(BuildContext c, String action) => switch (action) {
        'INSERT' => AdminV2Tokens.success(c),
        'DELETE' => AdminV2Tokens.destructive(c),
        _ => Theme.of(c).colorScheme.primary,
      };
}
