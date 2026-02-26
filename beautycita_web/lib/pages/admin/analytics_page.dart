import 'dart:math' as math;

import 'package:beautycita_core/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_analytics_provider.dart';
import '../../widgets/kpi_card.dart';

/// Admin analytics page — dashboard with multiple charts.
///
/// Layout (grid of chart cards):
/// - Bookings over time: LineChart (30 days)
/// - User growth: AreaChart (cumulative)
/// - Revenue by category: Horizontal BarChart
/// - Peak hours heatmap: Colored grid (hour x day-of-week)
/// - Retention: Metric cards (new, returning, churn)
/// - Top salons: Small table (top 5 by bookings)
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

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

              // Retention metrics
              _RetentionSection(
                ref: ref,
                isDesktop: isDesktop,
                isMobile: isMobile,
              ),
              const SizedBox(height: 24),

              // Row 1: Bookings + User growth
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _BookingsChart(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(child: _UserGrowthChart(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _BookingsChart(ref: ref),
                const SizedBox(height: 16),
                _UserGrowthChart(ref: ref),
              ],
              const SizedBox(height: 24),

              // Row 2: Revenue by category + Peak hours
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _RevenueByCategoryChart(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(child: _PeakHoursHeatmap(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _RevenueByCategoryChart(ref: ref),
                const SizedBox(height: 16),
                _PeakHoursHeatmap(ref: ref),
              ],
              const SizedBox(height: 24),

              // Top salons
              _TopSalonsTable(ref: ref),
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.analytics, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: BCSpacing.sm),
        Text(
          'Analiticas',
          style: (isMobile
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Retention Section ────────────────────────────────────────────────────────

class _RetentionSection extends StatelessWidget {
  const _RetentionSection({
    required this.ref,
    required this.isDesktop,
    required this.isMobile,
  });
  final WidgetRef ref;
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final retentionAsync = ref.watch(retentionMetricsProvider);

    return retentionAsync.when(
      loading: () => _LoadingCards(count: 3, isDesktop: isDesktop),
      error: (_, __) => _LoadingCards(count: 3, isDesktop: isDesktop),
      data: (metrics) {
        final cards = [
          KpiCard(
            icon: Icons.person_add,
            label: 'Nuevos usuarios (mes)',
            value: metrics.newUsersThisMonth.toString(),
            iconColor: const Color(0xFF4CAF50),
          ),
          KpiCard(
            icon: Icons.replay,
            label: 'Usuarios recurrentes',
            value: metrics.returningUsers.toString(),
            iconColor: const Color(0xFF2196F3),
          ),
          KpiCard(
            icon: Icons.trending_down,
            label: 'Tasa de abandono',
            value: '${metrics.churnRate.toStringAsFixed(1)}%',
            iconColor: metrics.churnRate > 20
                ? const Color(0xFFE53935)
                : const Color(0xFFFF9800),
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
          crossAxisCount: isDesktop ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.2 : 1.6,
          children: cards,
        );
      },
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards({required this.count, required this.isDesktop});
  final int count;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: isDesktop ? count : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 2.2 : 1.6,
      children: List.generate(count, (_) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Bookings Chart ───────────────────────────────────────────────────────────

class _BookingsChart extends StatelessWidget {
  const _BookingsChart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(bookingsOverTimeProvider);

    return _ChartCard(
      title: 'Reservas (30 dias)',
      child: dataAsync.when(
        loading: () => _chartLoading(colors),
        error: (_, __) => _chartError(theme),
        data: (data) {
          final maxVal = data.counts.isEmpty
              ? 10
              : data.counts.reduce(math.max);
          final maxY = maxVal > 0 ? (maxVal * 1.3).ceilToDouble() : 10.0;

          return SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        colors.onSurface.withValues(alpha: 0.9),
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      final label =
                          idx < data.labels.length ? data.labels[idx] : '';
                      return LineTooltipItem(
                        '$label: ${s.y.toInt()}',
                        TextStyle(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: _buildTitles(theme, colors, data.labels),
                gridData: _buildGrid(colors, maxY),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      data.counts.length,
                      (i) => FlSpot(i.toDouble(), data.counts[i].toDouble()),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: colors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  // Trend line (simple linear regression)
                  if (data.counts.isNotEmpty)
                    _trendLine(data.counts, colors),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  LineChartBarData _trendLine(List<int> counts, ColorScheme colors) {
    final n = counts.length;
    if (n < 2) {
      return LineChartBarData(spots: []);
    }

    // Simple linear regression
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (var i = 0; i < n; i++) {
      sumX += i;
      sumY += counts[i];
      sumXY += i * counts[i];
      sumX2 += i * i;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    return LineChartBarData(
      spots: [
        FlSpot(0, intercept),
        FlSpot((n - 1).toDouble(), slope * (n - 1) + intercept),
      ],
      isCurved: false,
      color: colors.error.withValues(alpha: 0.4),
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
      dashArray: [6, 4],
    );
  }
}

// ── User Growth Chart ────────────────────────────────────────────────────────

class _UserGrowthChart extends StatelessWidget {
  const _UserGrowthChart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(userGrowthProvider);

    return _ChartCard(
      title: 'Crecimiento de usuarios',
      child: dataAsync.when(
        loading: () => _chartLoading(colors),
        error: (_, __) => _chartError(theme),
        data: (data) {
          final maxVal = data.cumulativeCounts.isEmpty
              ? 10
              : data.cumulativeCounts.reduce(math.max);
          final minVal = data.cumulativeCounts.isEmpty
              ? 0
              : data.cumulativeCounts.reduce(math.min);
          final maxY = maxVal > 0 ? (maxVal * 1.1).ceilToDouble() : 10.0;
          final minY = minVal > 0 ? (minVal * 0.9).floorToDouble() : 0.0;

          return SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: minY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        colors.onSurface.withValues(alpha: 0.9),
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      final label =
                          idx < data.labels.length ? data.labels[idx] : '';
                      return LineTooltipItem(
                        '$label: ${s.y.toInt()} usuarios',
                        TextStyle(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: _buildTitles(theme, colors, data.labels),
                gridData: _buildGrid(colors, maxY),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      data.cumulativeCounts.length,
                      (i) => FlSpot(
                        i.toDouble(),
                        data.cumulativeCounts[i].toDouble(),
                      ),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFF2196F3),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2196F3).withValues(alpha: 0.2),
                          const Color(0xFF2196F3).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Revenue by Category ──────────────────────────────────────────────────────

class _RevenueByCategoryChart extends StatelessWidget {
  const _RevenueByCategoryChart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(revenueByCategoryProvider);

    return _ChartCard(
      title: 'Ingresos por categoria',
      child: dataAsync.when(
        loading: () => _chartLoading(colors),
        error: (_, __) => _chartError(theme),
        data: (items) {
          if (items.isEmpty) {
            return SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'Sin datos de categorias',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            );
          }

          final maxRevenue = items
              .map((e) => e.revenue)
              .reduce(math.max);

          return SizedBox(
            height: math.max(220, items.length * 44.0),
            child: BarChart(
              BarChartData(
                maxY: maxRevenue > 0 ? maxRevenue * 1.15 : 1000,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        colors.onSurface.withValues(alpha: 0.9),
                    getTooltipItem: (group, gi, rod, ri) {
                      final idx = group.x;
                      final name = idx < items.length
                          ? items[idx].categoryName
                          : '';
                      return BarTooltipItem(
                        '$name\n\$${rod.toY.toStringAsFixed(0)}',
                        TextStyle(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 100,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= items.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            items[idx].categoryName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: false,
                  getDrawingVerticalLine: (value) => FlLine(
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                alignment: BarChartAlignment.spaceAround,
                groupsSpace: 8,
                barGroups: List.generate(items.length, (i) {
                  final hue = (i * 40.0) % 360;
                  final barColor = HSLColor.fromAHSL(1, hue, 0.6, 0.5).toColor();
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: items[i].revenue,
                        color: barColor,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Peak Hours Heatmap ───────────────────────────────────────────────────────

class _PeakHoursHeatmap extends StatelessWidget {
  const _PeakHoursHeatmap({required this.ref});
  final WidgetRef ref;

  static const _dayLabels = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(peakHoursProvider);

    return _ChartCard(
      title: 'Horas pico',
      child: dataAsync.when(
        loading: () => _chartLoading(colors),
        error: (_, __) => _chartError(theme),
        data: (data) {
          final maxCount = data.maxCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hour labels (show every 3 hours)
              Row(
                children: [
                  const SizedBox(width: 36), // space for day labels
                  for (var h = 0; h < 24; h++)
                    Expanded(
                      child: h % 3 == 0
                          ? Text(
                              '${h}h',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: colors.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Grid rows
              for (var day = 0; day < 7; day++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          _dayLabels[day],
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      for (var hour = 0; hour < 24; hour++)
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              margin: const EdgeInsets.all(0.5),
                              decoration: BoxDecoration(
                                color: _heatColor(
                                  data.grid[day][hour],
                                  maxCount,
                                  colors.primary,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Menos',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  for (var level = 0; level < 5; level++)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _heatColorLevel(level, colors.primary),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    'Mas',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Color _heatColor(int count, int maxCount, Color base) {
    if (maxCount == 0 || count == 0) {
      return base.withValues(alpha: 0.05);
    }
    final ratio = count / maxCount;
    if (ratio < 0.25) return base.withValues(alpha: 0.15);
    if (ratio < 0.5) return base.withValues(alpha: 0.35);
    if (ratio < 0.75) return base.withValues(alpha: 0.6);
    return base.withValues(alpha: 0.9);
  }

  Color _heatColorLevel(int level, Color base) {
    return switch (level) {
      0 => base.withValues(alpha: 0.05),
      1 => base.withValues(alpha: 0.15),
      2 => base.withValues(alpha: 0.35),
      3 => base.withValues(alpha: 0.6),
      _ => base.withValues(alpha: 0.9),
    };
  }
}

// ── Top Salons Table ─────────────────────────────────────────────────────────

class _TopSalonsTable extends StatelessWidget {
  const _TopSalonsTable({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(topSalonsProvider);

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
              Icon(Icons.emoji_events, size: 20, color: const Color(0xFFFF9800)),
              const SizedBox(width: BCSpacing.sm),
              Text(
                'Top 5 Salones (este mes)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          dataAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Error al cargar',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            data: (salons) {
              if (salons.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin datos de salones',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BCSpacing.sm,
                      vertical: BCSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '#',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Salon',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Reservas',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < salons.length; i++) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BCSpacing.sm,
                        vertical: BCSpacing.sm,
                      ),
                      color: i.isEven
                          ? colors.onSurface.withValues(alpha: 0.02)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: _RankBadge(rank: i + 1),
                          ),
                          Expanded(
                            child: Text(
                              salons[i].salonName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              salons[i].bookingCount.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < salons.length - 1)
                      Divider(
                        height: 1,
                        color: colors.outlineVariant.withValues(alpha: 0.5),
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

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
    };

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Shared Chart Widgets ─────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

Widget _chartLoading(ColorScheme colors) {
  return SizedBox(
    height: 220,
    child: Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: colors.primary.withValues(alpha: 0.5),
      ),
    ),
  );
}

Widget _chartError(ThemeData theme) {
  return SizedBox(
    height: 220,
    child: Center(
      child: Text(
        'Error al cargar',
        style: theme.textTheme.bodySmall,
      ),
    ),
  );
}

FlTitlesData _buildTitles(
    ThemeData theme, ColorScheme colors, List<String> labels) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (value, meta) {
          if (value == meta.max || value == meta.min) {
            return const SizedBox.shrink();
          }
          return Text(
            value.toInt().toString(),
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
        interval: 7,
        getTitlesWidget: (value, meta) {
          final idx = value.toInt();
          if (idx < 0 || idx >= labels.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              labels[idx],
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );
        },
      ),
    ),
  );
}

FlGridData _buildGrid(ColorScheme colors, double maxY) {
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: maxY / 4,
    getDrawingHorizontalLine: (value) => FlLine(
      color: colors.outlineVariant.withValues(alpha: 0.5),
      strokeWidth: 1,
    ),
  );
}
