// Operaciones → Cola → drill-down.
//
// Generic per-queue list view. Each queue key maps to a query against
// the source table + a minimal "what does this row mean" projection. Tap
// a row to open a detail screen if one exists; otherwise show the raw
// payload as a fallback so the operator can still understand what's
// pending and decide what to do.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../services/supabase_client.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

enum ColaQueue {
  disputes,
  arco,
  roleChange,
  banking,
  alerts,
}

extension on ColaQueue {
  String get title => switch (this) {
        ColaQueue.disputes => 'Disputas abiertas',
        ColaQueue.arco => 'Solicitudes ARCO',
        ColaQueue.roleChange => 'Cambios de rol pendientes',
        ColaQueue.banking => 'Verificación bancaria',
        ColaQueue.alerts => 'Alertas del sistema',
      };

  String get explainer => switch (this) {
        ColaQueue.disputes => 'Disputas abiertas que requieren resolución por parte de un admin.',
        ColaQueue.arco => 'Solicitudes LFPDPPP de Acceso / Rectificación / Cancelación / Oposición de datos. Se debe responder dentro del plazo legal.',
        ColaQueue.roleChange => 'Cambios de rol marcados por un admin que esperan aprobación de superadmin.',
        ColaQueue.banking => 'Salones que subieron CLABE + ID y esperan verificación para empezar a recibir pagos.',
        ColaQueue.alerts => 'Eventos del sistema marcados para revisión humana (no son fallos automáticos — para eso, ver Salud).',
      };
}

final _drillRowsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, ColaQueue>((ref, queue) async {
  final c = SupabaseClientService.client;
  switch (queue) {
    case ColaQueue.disputes:
      final res = await c.from('disputes')
          .select('id, status, reason, created_at, appointment_id, business_id')
          .inFilter('status', ['open', 'pending', 'investigating'])
          .order('created_at', ascending: false)
          .limit(100);
      return (res as List).cast<Map<String, dynamic>>();
    case ColaQueue.arco:
      final res = await c.from('arco_requests')
          .select('id, request_type, status, user_email, submitted_at, due_at')
          .neq('status', 'resolved')
          .order('submitted_at', ascending: false)
          .limit(100);
      return (res as List).cast<Map<String, dynamic>>();
    case ColaQueue.roleChange:
      final res = await c.from('role_change_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      return (res as List).cast<Map<String, dynamic>>();
    case ColaQueue.banking:
      final res = await c.from('businesses')
          .select('id, name, city, clabe, id_verification_status, beneficiary_name')
          .eq('id_verification_status', 'pending')
          .neq('clabe', '')
          .order('created_at', ascending: false)
          .limit(100);
      return (res as List).cast<Map<String, dynamic>>();
    case ColaQueue.alerts:
      final res = await c.from('admin_alerts')
          .select('id, category, severity, payload, created_at')
          .filter('resolved_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(100);
      return (res as List).cast<Map<String, dynamic>>();
  }
});

class ColaDrillPage extends ConsumerWidget {
  const ColaDrillPage({super.key, required this.queue});
  final ColaQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRows = ref.watch(_drillRowsProvider(queue));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(queue.title, style: AdminV2Tokens.title(context)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_drillRowsProvider(queue)),
        child: asyncRows.when(
          loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
          error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
          data: (rows) {
            return ListView(
              padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
              children: [
                AdminCard(
                  child: Text(queue.explainer, style: AdminV2Tokens.body(context)),
                ),
                if (rows.isEmpty)
                  const AdminCard(
                    child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Cola vacía', body: 'Sin pendientes en este momento.'),
                  )
                else
                  ...rows.map((r) => _DrillRow(queue: queue, row: r)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrillRow extends StatelessWidget {
  const _DrillRow({required this.queue, required this.row});
  final ColaQueue queue;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (title, subtitle, severityColor) = _summarize(context, queue, row);
    final canDrill = queue == ColaQueue.banking; // only banking has a detail screen ready
    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: InkWell(
        onTap: !canDrill
            ? null
            : () {
                final id = row['id'] as String?;
                if (id == null) return;
                if (queue == ColaQueue.banking) {
                  context.push(AppRoutes.adminV3PersonasSalonDetail.replaceFirst(':id', id));
                }
              },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: severityColor ?? colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AdminV2Tokens.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AdminV2Tokens.spacingXS),
                  Text(subtitle, style: AdminV2Tokens.muted(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (canDrill) Icon(Icons.chevron_right, size: 18, color: AdminV2Tokens.subtle(context)),
          ],
        ),
      ),
    );
  }

  (String, String, Color?) _summarize(BuildContext c, ColaQueue q, Map<String, dynamic> r) {
    switch (q) {
      case ColaQueue.disputes:
        return (
          'Disputa  ·  ${r['status'] ?? ''}',
          (r['reason'] as String?) ?? '(sin motivo)',
          AdminV2Tokens.warning(c),
        );
      case ColaQueue.arco:
        return (
          'ARCO  ·  ${r['request_type'] ?? ''}',
          [r['user_email'] ?? '', 'Vence: ${_short(r['due_at'])}'].where((s) => (s as String).isNotEmpty).join(' · '),
          AdminV2Tokens.warning(c),
        );
      case ColaQueue.roleChange:
        return (
          'Cambio de rol pendiente',
          'Requiere aprobación de superadmin (con step-up)',
          AdminV2Tokens.warning(c),
        );
      case ColaQueue.banking:
        return (
          (r['name'] as String?) ?? 'Salón',
          'CLABE entregada · ID en revisión · ${(r['city'] as String?) ?? ''}',
          AdminV2Tokens.warning(c),
        );
      case ColaQueue.alerts:
        final sev = (r['severity'] as String?) ?? 'info';
        final color = switch (sev) {
          'critical' || 'error' => AdminV2Tokens.destructive(c),
          'warning' => AdminV2Tokens.warning(c),
          _ => AdminV2Tokens.subtle(c),
        };
        return (
          '${(r['category'] as String?) ?? '?'}  ·  $sev',
          _payloadSummary(r['payload']),
          color,
        );
    }
  }

  String _short(Object? iso) {
    if (iso is! String || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _payloadSummary(Object? p) {
    if (p is! Map) return '';
    final keys = p.keys.take(3).toList();
    return keys.map((k) => '$k: ${p[k]}').join('  ·  ');
  }
}
