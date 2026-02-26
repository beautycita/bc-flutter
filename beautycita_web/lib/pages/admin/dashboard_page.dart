import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../widgets/dashboard_charts.dart';
import '../../widgets/kpi_card.dart';

/// Admin dashboard — BC's daily command center.
///
/// Layout:
/// - Welcome header with today's date
/// - 4 KPI cards (revenue, active users, bookings today, registered salons)
/// - Activity feed + Alerts side by side
/// - Bookings bar chart + Revenue line chart side by side
///
/// Responsive:
/// - Desktop (>1200): 4 KPIs in a row, 2-column lower sections
/// - Tablet (800-1200): 2 KPIs per row, charts stacked
/// - Mobile (<800): 1 KPI per row, everything stacked
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final isTablet = WebBreakpoints.isTablet(width);
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
              // Welcome header
              _WelcomeHeader(isMobile: isMobile),
              const SizedBox(height: 24),

              // KPI cards
              _KpiSection(
                ref: ref,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              const SizedBox(height: 24),

              // Activity feed + Alerts
              if (isDesktop)
                _DesktopFeedAndAlerts(ref: ref)
              else
                _StackedFeedAndAlerts(ref: ref),
              const SizedBox(height: 24),

              // Charts
              if (isDesktop)
                _DesktopCharts(ref: ref)
              else
                _StackedCharts(ref: ref),
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
  const _WelcomeHeader({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    // Capitalize first letter
    final formattedDate =
        dateStr[0].toUpperCase() + dateStr.substring(1);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido, BC',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedDate,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Bienvenido, BC',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          formattedDate,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ── KPI Section ─────────────────────────────────────────────────────────────

class _KpiSection extends StatelessWidget {
  const _KpiSection({
    required this.ref,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  final WidgetRef ref;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final kpisAsync = ref.watch(dashboardKpisProvider);

    return kpisAsync.when(
      loading: () => const _KpiLoadingGrid(),
      error: (_, __) => const _KpiLoadingGrid(),
      data: (kpis) {
        final cards = [
          KpiCard(
            icon: Icons.payments_outlined,
            label: 'Ingresos del mes',
            value: _formatCurrency(kpis.monthlyRevenue),
            prefix: '\$',
            iconColor: const Color(0xFF4CAF50),
            changePercent: kpis.revenueChangePercent,
          ),
          KpiCard(
            icon: Icons.people_outlined,
            label: 'Usuarios activos',
            value: _formatNumber(kpis.activeUsers),
            iconColor: const Color(0xFF2196F3),
          ),
          KpiCard(
            icon: Icons.calendar_today_outlined,
            label: 'Reservas hoy',
            value: kpis.bookingsToday.toString(),
            iconColor: const Color(0xFFFF9800),
          ),
          KpiCard(
            icon: Icons.store_outlined,
            label: 'Salones registrados',
            value: kpis.registeredSalons.toString(),
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

        final crossAxisCount = isDesktop ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
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

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

/// Shimmer-like loading placeholder for KPI cards.
class _KpiLoadingGrid extends StatelessWidget {
  const _KpiLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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

// ── Activity Feed & Alerts ──────────────────────────────────────────────────

/// Desktop: side by side
class _DesktopFeedAndAlerts extends StatelessWidget {
  const _DesktopFeedAndAlerts({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _ActivityFeed(ref: ref)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _AlertsPanel(ref: ref)),
        ],
      ),
    );
  }
}

/// Tablet/Mobile: stacked
class _StackedFeedAndAlerts extends StatelessWidget {
  const _StackedFeedAndAlerts({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActivityFeed(ref: ref),
        const SizedBox(height: 16),
        _AlertsPanel(ref: ref),
      ],
    );
  }
}

/// Live activity feed showing recent bookings, users, cancellations.
class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feedAsync = ref.watch(activityFeedProvider);

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
              Icon(Icons.timeline, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Actividad reciente',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Live indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'En vivo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          feedAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No se pudo cargar la actividad',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 36,
                          color: colors.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin actividad reciente',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < items.length && i < 8; i++) ...[
                    _ActivityRow(item: items[i]),
                    if (i < items.length - 1 && i < 7)
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

/// A single row in the activity feed.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (IconData icon, Color color) = switch (item.type) {
      'booking' => (Icons.calendar_today, const Color(0xFF4CAF50)),
      'user' => (Icons.person_add, const Color(0xFF2196F3)),
      'salon' => (Icons.store, const Color(0xFF9C27B0)),
      'cancellation' => (Icons.cancel_outlined, const Color(0xFFE53935)),
      _ => (Icons.info_outline, colors.primary),
    };

    final timeAgo = _formatTimeAgo(item.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d/M').format(dt);
  }
}

/// Alerts panel showing counts of pending issues.
class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final alertsAsync = ref.watch(dashboardAlertsProvider);

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
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(width: 8),
              Text(
                'Alertas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              alertsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (alerts) {
                  if (alerts.total == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alerts.total}',
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          alertsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Error al cargar alertas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            data: (alerts) {
              if (alerts.total == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 36,
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Todo en orden',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (alerts.pendingDisputes > 0)
                    _AlertRow(
                      icon: Icons.gavel,
                      label: 'Disputas pendientes',
                      count: alerts.pendingDisputes,
                      color: const Color(0xFFE53935),
                    ),
                  if (alerts.unverifiedSalons > 0) ...[
                    if (alerts.pendingDisputes > 0) const SizedBox(height: 12),
                    _AlertRow(
                      icon: Icons.verified_outlined,
                      label: 'Salones sin verificar',
                      count: alerts.unverifiedSalons,
                      color: const Color(0xFFFF9800),
                    ),
                  ],
                  if (alerts.failedPayments > 0) ...[
                    if (alerts.pendingDisputes > 0 ||
                        alerts.unverifiedSalons > 0)
                      const SizedBox(height: 12),
                    _AlertRow(
                      icon: Icons.payment,
                      label: 'Pagos fallidos',
                      count: alerts.failedPayments,
                      color: const Color(0xFFE53935),
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

/// A single alert row with icon, label, and count badge.
class _AlertRow extends StatefulWidget {
  const _AlertRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  State<_AlertRow> createState() => _AlertRowState();
}

class _AlertRowState extends State<_AlertRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.color.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: widget.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.count}',
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Charts Section ──────────────────────────────────────────────────────────

/// Desktop: side by side
class _DesktopCharts extends StatelessWidget {
  const _DesktopCharts({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _BookingsChartSection(ref: ref)),
          const SizedBox(width: 16),
          Expanded(child: _RevenueChartSection(ref: ref)),
        ],
      ),
    );
  }
}

/// Tablet/Mobile: stacked
class _StackedCharts extends StatelessWidget {
  const _StackedCharts({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BookingsChartSection(ref: ref),
        const SizedBox(height: 16),
        _RevenueChartSection(ref: ref),
      ],
    );
  }
}

class _BookingsChartSection extends StatelessWidget {
  const _BookingsChartSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(weeklyBookingsProvider);
    return bookingsAsync.when(
      loading: () => _chartPlaceholder(context),
      error: (_, __) => _chartPlaceholder(context),
      data: (data) => BookingsBarChart(data: data),
    );
  }
}

class _RevenueChartSection extends StatelessWidget {
  const _RevenueChartSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final revenueAsync = ref.watch(revenueTrendProvider);
    return revenueAsync.when(
      loading: () => _chartPlaceholder(context),
      error: (_, __) => _chartPlaceholder(context),
      data: (data) => RevenueLineChart(data: data),
    );
  }
}

Widget _chartPlaceholder(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return Container(
    height: 260,
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.outlineVariant),
    ),
    child: Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: colors.primary.withValues(alpha: 0.5),
      ),
    ),
  );
}
