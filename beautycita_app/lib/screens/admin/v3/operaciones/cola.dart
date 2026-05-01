// Operaciones → Cola
//
// Unified work-queue surface — "what work needs human attention right now."
// Distinct from Salud (which monitors system health and metrics, not work).
//
// Top section: any unresolved admin_alerts as a warnings strip — these are
// signals that the system flagged for review (cron failure, payment-intent
// abandoned, etc).
//
// Below: a sub-queue card per work-stream. Each is drillable into a list
// of items the operator can act on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../providers/admin_v3_queue_provider.dart';
import '../../../../widgets/admin/v2/data_viz/kpi_tile.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class OperacionesCola extends ConsumerWidget {
  const OperacionesCola({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCounts = ref.watch(adminQueueCountsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminQueueCountsProvider),
      child: asyncCounts.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
          children: const [
            AdminCardSkeleton(heightHint: 100),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
          ],
        ),
        error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
        data: (c) {
          return ListView(
            padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
            children: [
              AdminCard(
                title: 'Cola de trabajo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pendientes que requieren acción humana — disputas, solicitudes ARCO, cambios de rol, verificaciones bancarias y alertas marcadas por el sistema. Para métricas de salud (latencia, Stripe, WA) ver pestaña Salud.',
                      style: AdminV2Tokens.muted(context),
                    ),
                    const SizedBox(height: AdminV2Tokens.spacingMD),
                    AdminKpiTile(
                      label: 'Total pendientes',
                      value: '${c.total}',
                      deltaHint: c.total == 0 ? 'Cola limpia.' : null,
                      deltaPositive: c.total == 0 ? true : null,
                    ),
                  ],
                ),
              ),
              if (c.alertsOpen > 0)
                _AlertsBanner(count: c.alertsOpen),
              _Row(
                queue: 'disputes',
                label: 'Disputas abiertas',
                count: c.disputesOpen,
                icon: Icons.gavel_outlined,
                hint: 'Cliente abrió disputa — requiere resolución.',
              ),
              _Row(
                queue: 'arco',
                label: 'Solicitudes ARCO',
                count: c.arcoOpen,
                icon: Icons.privacy_tip_outlined,
                hint: 'Solicitudes LFPDPPP de datos personales — plazo legal.',
              ),
              _Row(
                queue: 'role-change',
                label: 'Cambios de rol pendientes',
                count: c.roleChangePending,
                icon: Icons.swap_horiz_outlined,
                hint: 'Marcados por admin — esperan aprobación de superadmin.',
              ),
              _Row(
                queue: 'banking',
                label: 'Verificación bancaria',
                count: c.banking,
                icon: Icons.account_balance_outlined,
                hint: 'CLABE + ID enviados — falta aprobar para empezar pagos.',
              ),
              _Row(
                queue: 'alerts',
                label: 'Alertas del sistema',
                count: c.alertsOpen,
                icon: Icons.notifications_active_outlined,
                hint: 'Eventos marcados para revisión humana.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingMD),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: InkWell(
        onTap: () => context.push('${AppRoutes.adminV3OperacionesColaDrill.replaceFirst(':queue', 'alerts')}'),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 22, color: AdminV2Tokens.warning(context)),
            const SizedBox(width: AdminV2Tokens.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'alerta sin resolver' : 'alertas sin resolver'}',
                    style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w700, color: AdminV2Tokens.warning(context)),
                  ),
                  const SizedBox(height: 2),
                  Text('Toca para revisar', style: AdminV2Tokens.muted(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AdminV2Tokens.warning(context)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.queue,
    required this.label,
    required this.count,
    required this.icon,
    required this.hint,
  });
  final String queue;
  final String label;
  final int count;
  final IconData icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: InkWell(
        onTap: () => context.push(AppRoutes.adminV3OperacionesColaDrill.replaceFirst(':queue', queue)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AdminV2Tokens.spacingSM),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM),
              ),
              child: Icon(icon, color: colors.primary, size: 18),
            ),
            const SizedBox(width: AdminV2Tokens.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(hint, style: AdminV2Tokens.muted(context)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingMD, vertical: AdminV2Tokens.spacingXS),
              decoration: BoxDecoration(
                color: count > 0 ? AdminV2Tokens.warning(context).withValues(alpha: 0.18) : colors.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
              ),
              child: Text(
                '$count',
                style: AdminV2Tokens.body(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? AdminV2Tokens.warning(context) : AdminV2Tokens.subtle(context),
                ),
              ),
            ),
            const SizedBox(width: AdminV2Tokens.spacingXS),
            Icon(Icons.chevron_right, size: 18, color: AdminV2Tokens.subtle(context)),
          ],
        ),
      ),
    );
  }
}
