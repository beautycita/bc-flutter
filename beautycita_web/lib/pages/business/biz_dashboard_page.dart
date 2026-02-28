import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../providers/business_portal_provider.dart';
import '../../widgets/kpi_card.dart';

/// Business dashboard — stylist/owner daily command center.
///
/// KPI cards, today's appointments, monthly trend chart.
class BizDashboardPage extends ConsumerWidget {
  const BizDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: '$e'),
      data: (biz) {
        if (biz == null) return const _NoBusiness();
        return _DashboardContent(bizName: biz['name'] as String? ?? 'Mi Negocio');
      },
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.bizName});
  final String bizName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final isMobile = WebBreakpoints.isMobile(width);
        final padding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeHeader(bizName: bizName, isMobile: isMobile),
              const SizedBox(height: 24),
              _KpiSection(ref: ref, isDesktop: isDesktop, isMobile: isMobile),
              const SizedBox(height: 16),
              _QuickActions(isMobile: isMobile),
              const SizedBox(height: 24),
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _TodayAppointments(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _MonthlyChart(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _TodayAppointments(ref: ref),
                const SizedBox(height: 16),
                _MonthlyChart(ref: ref),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Welcome Header ──────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.bizName, required this.isMobile});
  final String bizName;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    final formattedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bizName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(formattedDate, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: Text(bizName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))),
        Text(formattedDate, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}

// ── KPI Section ─────────────────────────────────────────────────────────────

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.ref, required this.isDesktop, required this.isMobile});
  final WidgetRef ref;
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(businessStatsProvider);
    final trendAsync = ref.watch(businessWeeklyTrendProvider);
    final trend = trendAsync.valueOrNull;

    return statsAsync.when(
      loading: () => _loadingGrid(context),
      error: (_, __) => _loadingGrid(context),
      data: (stats) {
        final kpiData = [
          (Icons.calendar_today_outlined, 'Citas hoy', stats.appointmentsToday.toString(), const Color(0xFF4CAF50), WebRoutes.negocioCalendar, '', trend?.dailyCounts),
          (Icons.date_range_outlined, 'Citas esta semana', stats.appointmentsWeek.toString(), const Color(0xFF2196F3), WebRoutes.negocioCalendar, '', trend?.dailyCounts),
          (Icons.payments_outlined, 'Ingresos del mes', _formatCurrency(stats.revenueMonth), const Color(0xFFFF9800), WebRoutes.negocioPayments, '\$', trend?.dailyRevenue),
          (Icons.pending_actions_outlined, 'Por confirmar', stats.pendingConfirmations.toString(), const Color(0xFF9C27B0), WebRoutes.negocioCalendar, '', trend?.dailyPending),
          (Icons.star_outlined, 'Calificacion', stats.averageRating.toStringAsFixed(1), const Color(0xFFFFC107), WebRoutes.negocioReviews, '', null as List<double>?),
          (Icons.rate_review_outlined, 'Resenas', stats.totalReviews.toString(), const Color(0xFF00BCD4), WebRoutes.negocioReviews, '', null as List<double>?),
        ];

        final cards = [
          for (final d in kpiData)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(d.$5),
                child: KpiCard(
                  icon: d.$1,
                  label: d.$2,
                  value: d.$3,
                  iconColor: d.$4,
                  prefix: d.$6,
                  sparklineData: d.$7,
                ),
              ),
            ),
        ];

        if (isMobile) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i < cards.length - 2 ? 12 : 0),
                  child: Row(
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: 12),
                      if (i + 1 < cards.length) Expanded(child: cards[i + 1]) else const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
            ],
          );
        }

        return GridView.count(
          crossAxisCount: isDesktop ? 6 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.2 : 1.1,
          children: cards,
        );
      },
    );
  }

  Widget _loadingGrid(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: List.generate(6, (_) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Center(
            child: SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary.withValues(alpha: 0.5)),
            ),
          ),
        );
      }),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final actions = [
      (Icons.calendar_month_outlined, 'Ver calendario', WebRoutes.negocioCalendar),
      (Icons.spa_outlined, 'Agregar servicio', WebRoutes.negocioServices),
      (Icons.people_outlined, 'Gestionar staff', WebRoutes.negocioStaff),
      (Icons.settings_outlined, 'Configuracion', WebRoutes.negocioSettings),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final a in actions)
          ActionChip(
            avatar: Icon(a.$1, size: 18, color: colors.primary),
            label: Text(a.$2),
            onPressed: () => context.go(a.$3),
          ),
      ],
    );
  }
}

// ── Today's Appointments ────────────────────────────────────────────────────

class _TodayAppointments extends StatelessWidget {
  const _TodayAppointments({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    final range = (start: '${today}T00:00:00', end: '${today}T23:59:59');
    final apptsAsync = ref.watch(businessAppointmentsProvider(range));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text('Citas de hoy', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          apptsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Error al cargar', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)))),
            ),
            data: (appts) {
              if (appts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_available, size: 36, color: colors.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('Sin citas para hoy', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                );
              }

              // Show up to 10
              final displayed = appts.take(10).toList();
              return Column(
                children: [
                  for (var i = 0; i < displayed.length; i++) ...[
                    _AppointmentRow(appt: displayed[i]),
                    if (i < displayed.length - 1) Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.5)),
                  ],
                  if (appts.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('+${appts.length - 10} mas', style: theme.textTheme.bodySmall?.copyWith(color: colors.primary)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appt});
  final Map<String, dynamic> appt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = appt['status'] as String? ?? '';
    final startsAt = DateTime.tryParse(appt['starts_at'] as String? ?? '');
    final timeStr = startsAt != null ? DateFormat('HH:mm').format(startsAt) : '--:--';
    final service = appt['service_name'] as String? ?? 'Servicio';
    final customer = appt['customer_name'] as String? ?? '';
    final price = (appt['price'] as num?)?.toDouble() ?? 0;

    final statusColor = switch (status) {
      'confirmed' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'completed' => const Color(0xFF2196F3),
      'cancelled_customer' || 'cancelled_business' => const Color(0xFFE53935),
      _ => colors.onSurface.withValues(alpha: 0.5),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Time
          SizedBox(
            width: 50,
            child: Text(timeStr, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 12),
          // Status dot
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          // Service + customer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (customer.isNotEmpty)
                  Text(customer, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('\$${price.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Monthly Chart ───────────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chartAsync = ref.watch(businessMonthlyDailyProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text('Tendencia mensual', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          chartAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => SizedBox(
              height: 200,
              child: Center(child: Text('Error', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)))),
            ),
            data: (days) {
              if (days.isEmpty) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Sin datos', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)))),
                );
              }
              final maxCount = days.map((d) => (d['count'] as num?)?.toInt() ?? 0).fold(0, (a, b) => a > b ? a : b);
              if (maxCount == 0) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Sin citas este mes', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)))),
                );
              }

              return SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Tooltip(
                          message: 'Dia ${d['day']}: ${d['count']} citas, \$${((d['revenue'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            height: (((d['count'] as num?)?.toInt() ?? 0) / maxCount) * 180 + 4,
                            decoration: BoxDecoration(
                              color: d['day'] == DateTime.now().day
                                  ? colors.primary
                                  : colors.primary.withValues(alpha: 0.4),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Error / Empty States ────────────────────────────────────────────────────

class _NoBusiness extends StatelessWidget {
  const _NoBusiness();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No tienes un negocio registrado', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Contacta al administrador para crear tu perfil de negocio.', style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
