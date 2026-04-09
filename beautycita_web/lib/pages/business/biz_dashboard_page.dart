import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../utils/friendly_error.dart';
import '../../config/router.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/web_design_system.dart';

/// Remap a /negocio route to /demo when inside the demo shell.
String _demoAware(BuildContext context, String route) {
  final loc = GoRouterState.of(context).matchedLocation;
  if (loc.startsWith('/demo')) {
    return route.replaceFirst('/negocio', '/demo');
  }
  return route;
}

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
    // ignore: unused_local_variable — imported for future guard use
    final isDemo = ref.watch(isDemoProvider);
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
              // ── Financial sections ──
              _OutstandingDebtCard(ref: ref),
              _TaxDeductionsCard(ref: ref, isMobile: isMobile),
              const SizedBox(height: 16),
              _CfdiSection(ref: ref, isMobile: isMobile),
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
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    final formattedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebSectionHeader(
            label: 'Panel de control',
            title: bizName,
            centered: false,
            titleSize: 28,
          ),
          const SizedBox(height: 4),
          Text(formattedDate, style: theme.textTheme.bodyMedium?.copyWith(color: kWebTextSecondary)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: WebSectionHeader(
            label: 'Panel de control',
            title: bizName,
            centered: false,
            titleSize: 36,
          ),
        ),
        Text(formattedDate, style: theme.textTheme.bodyLarge?.copyWith(color: kWebTextSecondary)),
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
          (Icons.calendar_today_outlined, 'Citas hoy', stats.appointmentsToday.toString(), const Color(0xFF4CAF50), _demoAware(context, WebRoutes.negocioCalendar), '', trend?.dailyCounts),
          (Icons.date_range_outlined, 'Citas esta semana', stats.appointmentsWeek.toString(), const Color(0xFF2196F3), _demoAware(context, WebRoutes.negocioCalendar), '', trend?.dailyCounts),
          (Icons.payments_outlined, 'Ingresos del mes', _formatCurrency(stats.revenueMonth), const Color(0xFFFF9800), _demoAware(context, WebRoutes.negocioPayments), '\$', trend?.dailyRevenue),
          (Icons.pending_actions_outlined, 'Por confirmar', stats.pendingConfirmations.toString(), const Color(0xFF9C27B0), _demoAware(context, WebRoutes.negocioCalendar), '', trend?.dailyPending),
          (Icons.star_outlined, 'Calificacion', stats.averageRating.toStringAsFixed(1), const Color(0xFFFFC107), _demoAware(context, WebRoutes.negocioReviews), '', null as List<double>?),
          (Icons.rate_review_outlined, 'Resenas', stats.totalReviews.toString(), const Color(0xFF00BCD4), _demoAware(context, WebRoutes.negocioReviews), '', null as List<double>?),
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
    final actions = [
      (Icons.calendar_month_outlined, 'Ver calendario', _demoAware(context, WebRoutes.negocioCalendar)),
      (Icons.spa_outlined, 'Agregar servicio', _demoAware(context, WebRoutes.negocioServices)),
      (Icons.people_outlined, 'Gestionar staff', _demoAware(context, WebRoutes.negocioStaff)),
      (Icons.settings_outlined, 'Configuracion', _demoAware(context, WebRoutes.negocioSettings)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final a in actions)
          ActionChip(
            avatar: Icon(a.$1, size: 18, color: kWebPrimary),
            label: Text(a.$2),
            onPressed: () => context.go(a.$3),
            side: const BorderSide(color: kWebCardBorder),
            backgroundColor: kWebSurface,
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

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.today_outlined, size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text('Citas de hoy', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: kWebTextPrimary)),
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
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: kWebPrimary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_available_outlined, size: 28, color: kWebTextHint),
                        ),
                        const SizedBox(height: 8),
                        Text('Sin citas para hoy', style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint)),
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
                    if (i < displayed.length - 1) const Divider(height: 1, color: kWebCardBorder),
                  ],
                  if (appts.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('+${appts.length - 10} mas', style: theme.textTheme.bodySmall?.copyWith(color: kWebPrimary)),
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
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
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

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_outlined, size: 18, color: kWebSecondary),
              ),
              const SizedBox(width: 10),
              Text('Tendencia mensual', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: kWebTextPrimary)),
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

// ── Outstanding Debt Card ────────────────────────────────────────────────────

class _OutstandingDebtCard extends StatelessWidget {
  const _OutstandingDebtCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final taxAsync = ref.watch(businessTaxSummaryProvider);

    return taxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tax) {
        if (tax.outstandingDebt <= 0) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Color(0xFFE53935), size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deuda pendiente',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${tax.outstandingDebt.toStringAsFixed(2)} MXN',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '50% deduccion por servicio hasta liquidar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFE53935).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Tax & Deductions Card ───────────────────────────────────────────────────

class _TaxDeductionsCard extends StatelessWidget {
  const _TaxDeductionsCard({required this.ref, required this.isMobile});
  final WidgetRef ref;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final taxAsync = ref.watch(businessTaxSummaryProvider);
    final theme = Theme.of(context);

    return taxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tax) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: WebCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFFFF9800)),
                    ),
                    const SizedBox(width: 10),
                    Text('Impuestos y deducciones (YTD)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: kWebTextPrimary)),
                  ],
                ),
                const SizedBox(height: 20),
                // Tax breakdown grid
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _TaxMetric(label: 'Ingresos YTD', value: '\$${_fmtCurrency(tax.ytdRevenue)}', color: const Color(0xFF4CAF50)),
                    _TaxMetric(label: 'IVA 8%', value: '\$${_fmtCurrency(tax.ivaAmount)}', color: const Color(0xFFFF9800)),
                    _TaxMetric(label: 'ISR 2.5%', value: '\$${_fmtCurrency(tax.isrAmount)}', color: const Color(0xFFE53935)),
                    _TaxMetric(label: 'Total impuestos', value: '\$${_fmtCurrency(tax.totalTaxes)}', color: const Color(0xFF9C27B0)),
                    _TaxMetric(label: 'Gastos YTD', value: '\$${_fmtCurrency(tax.ytdExpenses)}', color: const Color(0xFF2196F3)),
                    _TaxMetric(
                      label: 'Presupuesto deducible',
                      value: '\$${_fmtCurrency(tax.deductionBudget)}',
                      color: tax.deductionBudget > 0 ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Deadline countdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: kWebPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: kWebPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${tax.daysUntilYearEnd} dias para registrar gastos deducibles antes del cierre fiscal',
                          style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Register expense button
                OutlinedButton.icon(
                  onPressed: () => _showRegistrarGastoDialog(context, ref),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Registrar Gasto'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'es_MX');
    return formatter.format(amount);
  }

  void _showRegistrarGastoDialog(BuildContext context, WidgetRef ref) {
    final conceptoController = TextEditingController();
    final montoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Gasto Deducible'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: conceptoController,
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  hintText: 'Ej: Productos de salon, renta...',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoController,
                decoration: const InputDecoration(
                  labelText: 'Monto (MXN)',
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final concepto = conceptoController.text.trim();
              final monto = double.tryParse(montoController.text.trim());
              if (concepto.isEmpty || monto == null || monto <= 0) return;

              try {
                final biz = await ref.read(currentBusinessProvider.future);
                if (biz == null) return;

                await BCSupabase.client.from(BCTables.businessExpenses).insert({
                  'business_id': biz['id'],
                  'concept': concepto,
                  'amount': monto,
                  'expense_date': DateTime.now().toIso8601String().substring(0, 10),
                });

                ref.invalidate(businessTaxSummaryProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gasto registrado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(friendlyError(e))),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _TaxMetric extends StatelessWidget {
  const _TaxMetric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── CFDI Section ────────────────────────────────────────────────────────────

class _CfdiSection extends StatelessWidget {
  const _CfdiSection({required this.ref, required this.isMobile});
  final WidgetRef ref;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final cfdiAsync = ref.watch(businessCfdiProvider);
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebTertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 18, color: kWebTertiary),
              ),
              const SizedBox(width: 10),
              Text('CFDI / Facturas', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: kWebTextPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          cfdiAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Error al cargar CFDI', style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint))),
            ),
            data: (records) {
              if (records.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: kWebTertiary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long_outlined, size: 28, color: kWebTextHint),
                        ),
                        const SizedBox(height: 8),
                        Text('Sin facturas registradas', style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint)),
                      ],
                    ),
                  ),
                );
              }

              if (isMobile) {
                return Column(
                  children: [
                    for (var i = 0; i < records.length; i++) ...[
                      _CfdiMobileRow(record: records[i]),
                      if (i < records.length - 1) const Divider(height: 1, color: kWebCardBorder),
                    ],
                  ],
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kWebBackground),
                  columns: const [
                    DataColumn(label: Text('Folio')),
                    DataColumn(label: Text('Periodo')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: [
                    for (final r in records) _buildCfdiRow(context, r),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  DataRow _buildCfdiRow(BuildContext context, Map<String, dynamic> r) {
    final folio = r['folio'] as String? ?? '--';
    final period = r['period'] as String? ?? '--';
    final status = r['status'] as String? ?? 'pending';
    final total = (r['total'] as num?)?.toDouble() ?? 0;

    final statusColor = switch (status) {
      'emitted' || 'timbrado' => const Color(0xFF4CAF50),
      'cancelled' || 'cancelado' => const Color(0xFFE53935),
      'pending' || 'pendiente' => const Color(0xFFFF9800),
      _ => const Color(0xFF999999),
    };

    return DataRow(cells: [
      DataCell(Text(folio, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
      DataCell(Text(period)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(status, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
        ),
      ),
      DataCell(Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }
}

class _CfdiMobileRow extends StatelessWidget {
  const _CfdiMobileRow({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folio = record['folio'] as String? ?? '--';
    final period = record['period'] as String? ?? '--';
    final status = record['status'] as String? ?? 'pending';
    final total = (record['total'] as num?)?.toDouble() ?? 0;

    final statusColor = switch (status) {
      'emitted' || 'timbrado' => const Color(0xFF4CAF50),
      'cancelled' || 'cancelado' => const Color(0xFFE53935),
      'pending' || 'pendiente' => const Color(0xFFFF9800),
      _ => const Color(0xFF999999),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(folio, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                Text(period, style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Text('\$${total.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kWebPrimary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.store_outlined, size: 40, color: kWebTextHint),
          ),
          const SizedBox(height: 16),
          Text('No tienes un negocio registrado', style: theme.textTheme.titleMedium?.copyWith(color: kWebTextPrimary)),
          const SizedBox(height: 8),
          Text('Contacta al administrador para crear tu perfil de negocio.', style: theme.textTheme.bodyMedium?.copyWith(color: kWebTextSecondary)),
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
