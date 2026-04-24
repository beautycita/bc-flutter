import 'dart:math' as math;

import 'package:beautycita_core/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_finance_dashboard_provider.dart'
    show commissionDetailProvider, CommissionMonthlySummary;
import '../../providers/admin_finance_provider.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/web_design_system.dart';

/// Admin finance page — dashboard-style with charts and summary cards.
///
/// Layout:
/// - Top row: KPI cards (Total revenue, Platform fees, Pending payouts, Active subscriptions)
/// - Revenue chart: LineChart showing monthly revenue for last 12 months
/// - Payment methods breakdown: Pie chart (Stripe vs BTCPay vs Cash)
/// - Payout history table
/// - Platform fee collection table
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final isMobile = WebBreakpoints.isMobile(width);
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              _PageHeader(isMobile: isMobile),
              const SizedBox(height: 24),

              // KPI cards
              _FinanceKpis(ref: ref, isDesktop: isDesktop, isMobile: isMobile),
              const SizedBox(height: 24),

              // Charts row
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _RevenueChart(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _PaymentMethodsChart(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _RevenueChart(ref: ref),
                const SizedBox(height: 16),
                _PaymentMethodsChart(ref: ref),
              ],
              const SizedBox(height: 24),

              // Tables row
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _PayoutHistoryTable(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(child: _PlatformFeesTable(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _PayoutHistoryTable(ref: ref),
                const SizedBox(height: 16),
                _PlatformFeesTable(ref: ref),
              ],
              const SizedBox(height: 24),

              // Commission detail by month & source
              _CommissionDetailSection(
                ref: ref,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Page Header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return WebSectionHeader(
      label: 'Panel Financiero',
      title: 'Finanzas',
      centered: false,
      titleSize: isMobile ? 28 : 36,
    );
  }
}

// ── KPI Section ──────────────────────────────────────────────────────────────

class _FinanceKpis extends StatelessWidget {
  const _FinanceKpis({
    required this.ref,
    required this.isDesktop,
    required this.isMobile,
  });
  final WidgetRef ref;
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final kpisAsync = ref.watch(financeKpisProvider);
    final colors = Theme.of(context).colorScheme;

    return kpisAsync.when(
      loading: () => _KpiLoadingRow(colors: colors),
      error: (_, __) => _KpiLoadingRow(colors: colors),
      data: (kpis) {
        final cards = [
          KpiCard(
            icon: Icons.trending_up,
            label: 'Ingresos totales',
            value: _fmt(kpis.totalRevenue),
            prefix: '\$',
            iconColor: const Color(0xFF4CAF50),
            changePercent: kpis.revenueChangePercent,
          ),
          KpiCard(
            icon: Icons.percent,
            label: 'Comisiones plataforma',
            value: _fmt(kpis.platformFees),
            prefix: '\$',
            iconColor: const Color(0xFF2196F3),
          ),
          KpiCard(
            icon: Icons.schedule,
            label: 'Pagos pendientes',
            value: _fmt(kpis.pendingPayouts),
            prefix: '\$',
            iconColor: const Color(0xFFFF9800),
          ),
          KpiCard(
            icon: Icons.card_membership,
            label: 'Suscripciones activas',
            value: kpis.activeSubscriptions.toString(),
            iconColor: const Color(0xFF9C27B0),
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                if (card != cards.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.8 : 1.6,
          children: cards,
        );
      },
    );
  }

  String _fmt(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }
}

class _KpiLoadingRow extends StatelessWidget {
  const _KpiLoadingRow({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: List.generate(4, (_) {
        return Container(
          decoration: BoxDecoration(
            color: kWebSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kWebCardBorder),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kWebPrimary.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Revenue Chart ────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final revenueAsync = ref.watch(monthlyRevenueProvider);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresos mensuales (12 meses)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: kWebTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: revenueAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary.withValues(alpha: 0.5),
                ),
              ),
              error: (_, __) => Center(
                child: Text('Error al cargar',
                    style: theme.textTheme.bodySmall),
              ),
              data: (data) => _buildLineChart(context, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, MonthlyRevenue data) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final maxVal = data.values.isEmpty
        ? 1000.0
        : data.values.reduce(math.max);
    final maxY = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 1000.0;

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.onSurface.withValues(alpha: 0.9),
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            tooltipRoundedRadius: 6,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final idx = spot.x.toInt();
                final label =
                    idx < data.labels.length ? data.labels[idx] : '';
                return LineTooltipItem(
                  '$label\n\$${spot.y.toStringAsFixed(0)}',
                  TextStyle(
                    color: colors.surface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                final formatted = value >= 1000
                    ? '\$${(value / 1000).toStringAsFixed(0)}k'
                    : '\$${value.toInt()}';
                return Text(
                  formatted,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.labels.length) {
                  return const SizedBox.shrink();
                }
                // Show every other label to avoid crowding
                if (idx % 2 != 0 && data.labels.length > 8) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data.labels[idx],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.values.length,
              (i) => FlSpot(i.toDouble(), data.values[i]),
            ),
            isCurved: true,
            curveSmoothness: 0.3,
            color: colors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: colors.primary,
                strokeWidth: 1.5,
                strokeColor: colors.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colors.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Methods Chart ────────────────────────────────────────────────────

class _PaymentMethodsChart extends StatelessWidget {
  const _PaymentMethodsChart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metodos de pago (mes actual)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: kWebTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: methodsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary.withValues(alpha: 0.5),
                ),
              ),
              error: (_, __) => Center(
                child: Text('Error al cargar',
                    style: theme.textTheme.bodySmall),
              ),
              data: (data) => _buildPieChart(context, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, PaymentMethodBreakdown data) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (data.total == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Sin datos de pagos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    const stripeColor = Color(0xFF6772E5);
    const btcColor = Color(0xFFF7931A);
    const cashColor = Color(0xFF4CAF50);

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                if (data.stripe > 0)
                  PieChartSectionData(
                    value: data.stripe,
                    color: stripeColor,
                    title:
                        '${(data.stripe / data.total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    radius: 50,
                  ),
                if (data.btcpay > 0)
                  PieChartSectionData(
                    value: data.btcpay,
                    color: btcColor,
                    title:
                        '${(data.btcpay / data.total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    radius: 50,
                  ),
                if (data.cash > 0)
                  PieChartSectionData(
                    value: data.cash,
                    color: cashColor,
                    title:
                        '${(data.cash / data.total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    radius: 50,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: stripeColor, label: 'Stripe'),
            const SizedBox(width: 16),
            _LegendItem(color: btcColor, label: 'Bitcoin'),
            const SizedBox(width: 16),
            _LegendItem(color: cashColor, label: 'Efectivo'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }
}

// ── Payout History Table ─────────────────────────────────────────────────────

class _PayoutHistoryTable extends StatelessWidget {
  const _PayoutHistoryTable({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final payoutsAsync = ref.watch(payoutHistoryProvider);
    final dateFmt = DateFormat('d/MM/yy', 'es');

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de pagos',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: kWebTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          payoutsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Error al cargar pagos',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            data: (payouts) {
              if (payouts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin historial de pagos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Header
                  _TableHeader(columns: const [
                    'Fecha',
                    'Salon',
                    'Monto',
                    'Estado',
                    'Metodo',
                  ]),
                  const Divider(height: 1),
                  // Rows
                  for (var i = 0;
                      i < payouts.length && i < 10;
                      i++) ...[
                    _PayoutRow(
                      payout: payouts[i],
                      dateFmt: dateFmt,
                      isEven: i.isEven,
                    ),
                    if (i < payouts.length - 1 && i < 9)
                      Divider(
                        height: 1,
                        color:
                            colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.payout,
    required this.dateFmt,
    required this.isEven,
  });
  final PayoutRecord payout;
  final DateFormat dateFmt;
  final bool isEven;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (Color statusBg, Color statusFg) = switch (payout.status) {
      'succeeded' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'pending' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'processing' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'failed' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.sm,
        vertical: BCSpacing.sm,
      ),
      color: isEven
          ? kWebBackground
          : kWebSurface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateFmt.format(payout.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: kWebTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              payout.salonName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              '\$${payout.amount.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                payout.statusLabel,
                style: TextStyle(
                  color: statusFg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: Text(
              payout.method == 'stripe' ? 'Stripe' : 'Transferencia',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Platform Fees Table ──────────────────────────────────────────────────────

class _PlatformFeesTable extends StatelessWidget {
  const _PlatformFeesTable({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feesAsync = ref.watch(platformFeesProvider);
    final dateFmt = DateFormat('d/MM/yy', 'es');

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comisiones de plataforma',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: kWebTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          feesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Error al cargar comisiones',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            data: (fees) {
              if (fees.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin comisiones registradas',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  _TableHeader(columns: const [
                    'Fecha',
                    'Reserva',
                    'Comision',
                    'Estado',
                  ]),
                  const Divider(height: 1),
                  for (var i = 0; i < fees.length && i < 10; i++) ...[
                    _FeeRow(
                      fee: fees[i],
                      dateFmt: dateFmt,
                      isEven: i.isEven,
                    ),
                    if (i < fees.length - 1 && i < 9)
                      Divider(
                        height: 1,
                        color:
                            colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.fee,
    required this.dateFmt,
    required this.isEven,
  });
  final PlatformFeeRecord fee;
  final DateFormat dateFmt;
  final bool isEven;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.sm,
        vertical: BCSpacing.sm,
      ),
      color: isEven
          ? kWebBackground
          : kWebSurface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateFmt.format(fee.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: kWebTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              fee.bookingRef != null
                  ? '#${fee.bookingRef!.substring(0, 8)}'
                  : '-',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '\$${fee.feeAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4CAF50),
              ),
            ),
          ),
          Expanded(
            child: Text(
              fee.status == 'succeeded' ? 'Cobrada' : 'Pendiente',
              style: theme.textTheme.bodySmall?.copyWith(
                color: fee.status == 'succeeded'
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared table header ──────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.sm,
        vertical: BCSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kWebPrimary.withValues(alpha: 0.04),
            kWebSecondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: kWebCardBorder),
        ),
      ),
      child: Row(
        children: [
          for (final col in columns)
            Expanded(
              child: Text(
                col,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Commission Detail by Month & Source ──────────────────────────────────

class _CommissionDetailSection extends StatelessWidget {
  const _CommissionDetailSection({
    required this.ref,
    required this.isDesktop,
  });
  final WidgetRef ref;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(commissionDetailProvider);

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
                child: const Icon(Icons.receipt_long_outlined,
                    size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                'Detalle de Comisiones por Mes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          dataAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text('Error al cargar comisiones',
                  style: theme.textTheme.bodySmall),
            ),
            data: (data) {
              if (data.months.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 40,
                            color: colors.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                        Text(
                          'Sin registros de comisiones',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary KPIs
                  Row(
                    children: [
                      Expanded(
                        child: _CommissionKpi(
                          label: 'Total cobrado',
                          amount: data.totalCollected,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CommissionKpi(
                          label: 'Pendiente de cobro',
                          amount: data.totalPending,
                          color: const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Monthly table
                  if (isDesktop)
                    _DesktopCommissionTable(months: data.months)
                  else
                    _MobileCommissionList(months: data.months),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommissionKpi extends StatelessWidget {
  const _CommissionKpi({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
          Text(
            '\$${_fmtCommission(amount)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopCommissionTable extends StatelessWidget {
  const _DesktopCommissionTable({required this.months});
  final List<CommissionMonthlySummary> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DataTable(
      columnSpacing: 24,
      headingRowHeight: 40,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      headingTextStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.onSurface.withValues(alpha: 0.7),
      ),
      dataTextStyle: theme.textTheme.bodySmall,
      columns: const [
        DataColumn(label: Text('Periodo')),
        DataColumn(label: Text('Reservas (3%)'), numeric: true),
        DataColumn(label: Text('# Reservas'), numeric: true),
        DataColumn(label: Text('Productos (7%+3%)'), numeric: true),
        DataColumn(label: Text('# Productos'), numeric: true),
        DataColumn(label: Text('Total'), numeric: true),
      ],
      rows: months.map((m) {
        return DataRow(cells: [
          DataCell(Text(m.period,
              style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text('\$${_fmtCommission(m.appointmentCommissions)}')),
          DataCell(Text('${m.appointmentCount}')),
          DataCell(Text('\$${_fmtCommission(m.productCommissions)}')),
          DataCell(Text('${m.productCount}')),
          DataCell(Text(
            '\$${_fmtCommission(m.total)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          )),
        ]);
      }).toList(),
    );
  }
}

class _MobileCommissionList extends StatelessWidget {
  const _MobileCommissionList({required this.months});
  final List<CommissionMonthlySummary> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        for (var i = 0; i < months.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(months[i].period,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('\$${_fmtCommission(months[i].total)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4CAF50),
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reservas (3%)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.5),
                            )),
                        Text(
                            '\$${_fmtCommission(months[i].appointmentCommissions)} (${months[i].appointmentCount})',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Productos (7%+3%)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.5),
                            )),
                        Text(
                            '\$${_fmtCommission(months[i].productCommissions)} (${months[i].productCount})',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (i < months.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

String _fmtCommission(double amount) {
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 100000) return '${(amount / 1000).toStringAsFixed(0)}k';
  if (amount >= 1000) return NumberFormat('#,##0', 'es').format(amount.round());
  return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
}
