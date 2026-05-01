// Operaciones → Cola
//
// Unified work-queue surface. Each card shows a sub-queue's pending count
// and lets the operator drill in. Sub-queue drilldown screens land in
// follow-up sessions; the count card pattern means BC sees the work-load
// shape immediately even before drilldowns ship.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
            AdminCardSkeleton(heightHint: 80),
          ],
        ),
        error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
        data: (c) {
          if (c.total == 0) {
            return ListView(
              children: const [
                SizedBox(height: AdminV2Tokens.spacingXL),
                Center(child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin pendientes', body: 'Cola limpia.')),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
            children: [
              AdminCard(
                title: 'Resumen',
                child: AdminKpiTile(label: 'Total pendientes', value: '${c.total}'),
              ),
              _Row(label: 'Disputas abiertas', count: c.disputesOpen, icon: Icons.gavel_outlined),
              _Row(label: 'Solicitudes ARCO', count: c.arcoOpen, icon: Icons.privacy_tip_outlined),
              _Row(label: 'Cambios de rol pendientes', count: c.roleChangePending, icon: Icons.swap_horiz_outlined),
              _Row(label: 'Verificación bancaria', count: c.banking, icon: Icons.account_balance_outlined),
              _Row(label: 'Alertas del sistema', count: c.alertsOpen, icon: Icons.notifications_active_outlined),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.count, required this.icon});
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
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
          Expanded(child: Text(label, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600))),
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
        ],
      ),
    );
  }
}
