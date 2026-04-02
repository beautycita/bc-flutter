import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _StaffStat {
  const _StaffStat({
    required this.staffId,
    required this.name,
    required this.revenue,
    required this.bookingCount,
    required this.commission,
    required this.commissionRate,
  });
  final String staffId;
  final String name;
  final double revenue;
  final int bookingCount;
  final double commission;
  final double commissionRate;

  double get avgTicket =>
      bookingCount > 0 ? revenue / bookingCount : 0;
}

class _ServiceStat {
  const _ServiceStat({
    required this.serviceName,
    required this.count,
    required this.revenue,
  });
  final String serviceName;
  final int count;
  final double revenue;
}

// ── Providers ────────────────────────────────────────────────────────────────

final _staffAnalyticsProvider = FutureProvider.autoDispose
    .family<List<_StaffStat>, String>((ref, bizId) async {
  final client = BCSupabase.client;

  // Appointments grouped by staff with revenue sum
  final apptRows = await client
      .from('appointments')
      .select('staff_id, staff_name, price')
      .eq('business_id', bizId)
      .eq('status', 'completed');

  final List appts = apptRows as List;

  // Group by staff
  final Map<String, Map<String, dynamic>> byStaff = {};
  for (final a in appts) {
    final sid = a['staff_id']?.toString() ?? 'unknown';
    final name = a['staff_name'] as String? ?? 'Sin nombre';
    final price = (a['price'] as num?)?.toDouble() ?? 0;

    byStaff.putIfAbsent(sid, () => {
          'name': name,
          'revenue': 0.0,
          'count': 0,
        });
    byStaff[sid]!['revenue'] =
        (byStaff[sid]!['revenue'] as double) + price;
    byStaff[sid]!['count'] =
        (byStaff[sid]!['count'] as int) + 1;
  }

  // Commissions
  final commRows = await client
      .from('staff_commissions')
      .select()
      .eq('business_id', bizId);
  final Map<String, Map<String, dynamic>> commByStaff = {
    for (final c in (commRows as List))
      c['staff_id'].toString(): c as Map<String, dynamic>,
  };

  final stats = byStaff.entries.map((e) {
    final sid = e.key;
    final commRow = commByStaff[sid];
    final rate =
        (commRow?['commission_rate'] as num?)?.toDouble() ?? 0;
    final revenue = e.value['revenue'] as double;
    return _StaffStat(
      staffId: sid,
      name: e.value['name'] as String,
      revenue: revenue,
      bookingCount: e.value['count'] as int,
      commission: revenue * rate / 100,
      commissionRate: rate,
    );
  }).toList();

  stats.sort((a, b) => b.revenue.compareTo(a.revenue));
  return stats;
});

final _serviceAnalyticsProvider = FutureProvider.autoDispose
    .family<List<_ServiceStat>, String>((ref, bizId) async {
  final rows = await BCSupabase.client
      .from('appointments')
      .select('service_name, price')
      .eq('business_id', bizId)
      .eq('status', 'completed');

  final Map<String, Map<String, dynamic>> bySvc = {};
  for (final a in (rows as List)) {
    final name = a['service_name'] as String? ?? 'Sin nombre';
    final price = (a['price'] as num?)?.toDouble() ?? 0;
    bySvc.putIfAbsent(name, () => {'count': 0, 'revenue': 0.0});
    bySvc[name]!['count'] = (bySvc[name]!['count'] as int) + 1;
    bySvc[name]!['revenue'] =
        (bySvc[name]!['revenue'] as double) + price;
  }

  final stats = bySvc.entries
      .map((e) => _ServiceStat(
            serviceName: e.key,
            count: e.value['count'] as int,
            revenue: e.value['revenue'] as double,
          ))
      .toList();
  stats.sort((a, b) => b.revenue.compareTo(a.revenue));
  return stats;
});

// ── Page ─────────────────────────────────────────────────────────────────────

class BizAnalyticsPage extends ConsumerWidget {
  const BizAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _AnalyticsContent(bizId: biz['id'] as String);
      },
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _AnalyticsContent extends ConsumerWidget {
  const _AnalyticsContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffAnalyticsProvider(bizId));
    final svcAsync = ref.watch(_serviceAnalyticsProvider(bizId));
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Text(
            'Analiticas de Staff',
            style: theme.textTheme.titleLarge?.copyWith(
              color: kWebTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rendimiento del equipo y desglose por servicio (citas completadas).',
            style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
          ),
          const SizedBox(height: 28),

          // Summary stat cards
          staffAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (staff) => _SummaryCards(staff: staff),
          ),

          const SizedBox(height: 28),

          // Two-column layout: staff table | service breakdown
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: staffAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                        data: (staff) => _StaffTable(staff: staff),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: svcAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                        data: (svcs) => _ServiceBreakdown(svcs: svcs),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  staffAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (staff) => _StaffTable(staff: staff),
                  ),
                  const SizedBox(height: 20),
                  svcAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (svcs) => _ServiceBreakdown(svcs: svcs),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Commission summary
          staffAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (staff) => _CommissionSummary(staff: staff),
          ),
        ],
      ),
    );
  }
}

// ── Summary Cards ─────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.staff});
  final List<_StaffStat> staff;

  @override
  Widget build(BuildContext context) {
    final totalRevenue =
        staff.fold<double>(0, (sum, s) => sum + s.revenue);
    final totalBookings =
        staff.fold<int>(0, (sum, s) => sum + s.bookingCount);
    final totalCommission =
        staff.fold<double>(0, (sum, s) => sum + s.commission);
    final avgTicket =
        totalBookings > 0 ? totalRevenue / totalBookings : 0.0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(
          icon: Icons.attach_money_outlined,
          label: 'Ingresos Totales',
          value: '\$${totalRevenue.toStringAsFixed(0)}',
          color: kWebSuccess,
        ),
        _StatCard(
          icon: Icons.event_available_outlined,
          label: 'Citas Completadas',
          value: '$totalBookings',
          color: kWebPrimary,
        ),
        _StatCard(
          icon: Icons.trending_up_outlined,
          label: 'Ticket Promedio',
          value: '\$${avgTicket.toStringAsFixed(0)}',
          color: kWebSecondary,
        ),
        _StatCard(
          icon: Icons.paid_outlined,
          label: 'Comisiones Totales',
          value: '\$${totalCommission.toStringAsFixed(0)}',
          color: kWebTertiary,
        ),
        _StatCard(
          icon: Icons.people_outlined,
          label: 'Staff Activo',
          value: '${staff.length}',
          color: kWebWarning,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: kWebTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
          ),
        ],
      ),
    );
  }
}

// ── Staff Table ───────────────────────────────────────────────────────────────

class _StaffTable extends StatelessWidget {
  const _StaffTable({required this.staff});
  final List<_StaffStat> staff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Ranking de Staff',
              style: theme.textTheme.titleMedium?.copyWith(
                color: kWebTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: kWebCardBorder),

          if (staff.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin datos de staff',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kWebTextHint),
                ),
              ),
            )
          else ...[
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              color: kWebBackground,
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                      flex: 3,
                      child: _Th(theme, 'Nombre')),
                  Expanded(
                      flex: 2,
                      child: _Th(theme, 'Ingresos')),
                  Expanded(
                      flex: 1,
                      child: _Th(theme, 'Citas')),
                  Expanded(
                      flex: 2,
                      child: _Th(theme, 'Ticket Prom.')),
                ],
              ),
            ),
            for (int i = 0; i < staff.length; i++) ...[
              const Divider(height: 1, color: kWebCardBorder),
              _StaffRow(rank: i + 1, stat: staff[i], theme: theme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _Th(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: kWebTextHint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow(
      {required this.rank, required this.stat, required this.theme});
  final int rank;
  final _StaffStat stat;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : kWebTextHint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              stat.name,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${stat.revenue.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${stat.bookingCount}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${stat.avgTicket.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Service Breakdown ─────────────────────────────────────────────────────────

class _ServiceBreakdown extends StatelessWidget {
  const _ServiceBreakdown({required this.svcs});
  final List<_ServiceStat> svcs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRevenue =
        svcs.isEmpty ? 1.0 : svcs.first.revenue;

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Ingresos por Servicio',
              style: theme.textTheme.titleMedium?.copyWith(
                color: kWebTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: kWebCardBorder),

          if (svcs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin datos de servicios',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kWebTextHint),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final s in svcs.take(10))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ServiceBar(
                        svc: s,
                        maxRevenue: maxRevenue,
                        theme: theme,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceBar extends StatelessWidget {
  const _ServiceBar({
    required this.svc,
    required this.maxRevenue,
    required this.theme,
  });
  final _ServiceStat svc;
  final double maxRevenue;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final pct = maxRevenue > 0 ? svc.revenue / maxRevenue : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                svc.serviceName,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: kWebTextPrimary, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${svc.revenue.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              '(${svc.count}x)',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: kWebTextHint),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: kWebCardBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(kWebPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Commission Summary ────────────────────────────────────────────────────────

class _CommissionSummary extends StatelessWidget {
  const _CommissionSummary({required this.staff});
  final List<_StaffStat> staff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final withComm = staff.where((s) => s.commission > 0).toList();

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Resumen de Comisiones',
              style: theme.textTheme.titleMedium?.copyWith(
                color: kWebTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: kWebCardBorder),

          if (withComm.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay comisiones configuradas',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kWebTextHint),
                ),
              ),
            )
          else ...[
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              color: kWebBackground,
              child: Row(
                children: [
                  Expanded(flex: 3, child: _Th(theme, 'Staff')),
                  Expanded(flex: 2, child: _Th(theme, 'Ingresos')),
                  Expanded(flex: 1, child: _Th(theme, 'Tasa %')),
                  Expanded(flex: 2, child: _Th(theme, 'Comision')),
                ],
              ),
            ),
            for (int i = 0; i < withComm.length; i++) ...[
              const Divider(height: 1, color: kWebCardBorder),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        withComm[i].name,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebTextPrimary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${withComm[i].revenue.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${withComm[i].commissionRate.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${withComm[i].commission.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 1, color: kWebCardBorder),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'TOTAL',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: kWebTextPrimary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(flex: 2, child: const SizedBox()),
                  Expanded(flex: 1, child: const SizedBox()),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${withComm.fold<double>(0, (s, x) => s + x.commission).toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: kWebPrimary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _Th(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: kWebTextHint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}
