import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../widgets/dashboard_charts.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/web_design_system.dart';

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
          child: StaggeredFadeIn(
            spacing: 24,
            children: [
              // Welcome header
              _WelcomeHeader(isMobile: isMobile),

              // KPI cards
              _KpiSection(
                ref: ref,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),

              // Activity feed + Alerts
              if (isDesktop)
                _DesktopFeedAndAlerts(ref: ref)
              else
                _StackedFeedAndAlerts(ref: ref),

              // Charts
              if (isDesktop)
                _DesktopCharts(ref: ref)
              else
                _StackedCharts(ref: ref),
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
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    // Capitalize first letter
    final formattedDate =
        dateStr[0].toUpperCase() + dateStr.substring(1);

    if (isMobile) {
      return WebSectionHeader(
        label: formattedDate,
        title: 'Bienvenido, BC',
        centered: false,
        titleSize: 28,
      );
    }

    return Row(
      children: [
        Expanded(
          child: WebSectionHeader(
            label: formattedDate,
            title: 'Bienvenido, BC',
            centered: false,
            titleSize: 36,
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
            iconColor: kWebSuccess,
            changePercent: kpis.revenueChangePercent,
          ),
          KpiCard(
            icon: Icons.people_outlined,
            label: 'Usuarios activos',
            value: _formatNumber(kpis.activeUsers),
            iconColor: kWebInfo,
          ),
          KpiCard(
            icon: Icons.calendar_today_outlined,
            label: 'Reservas hoy',
            value: kpis.bookingsToday.toString(),
            iconColor: kWebWarning,
          ),
          KpiCard(
            icon: Icons.store_outlined,
            label: 'Salones registrados',
            value: kpis.registeredSalons.toString(),
            iconColor: kWebSecondary,
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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = WebBreakpoints.isMobile(width);
    final isDesktop = WebBreakpoints.isDesktop(width);
    final crossAxisCount = isMobile ? 1 : isDesktop ? 4 : 2;
    final aspectRatio = isMobile ? 3.0 : isDesktop ? 1.8 : 1.6;

    if (isMobile) {
      return Column(
        children: List.generate(4, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < 3 ? 12 : 0),
            child: Container(
              height: 80,
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
            ),
          );
        }),
      );
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio,
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
    final feedAsync = ref.watch(activityFeedProvider);

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
                child: const Icon(Icons.timeline_outlined, size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                'Actividad reciente',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                ),
              ),
              const Spacer(),
              // Live indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: kWebSuccess,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kWebSuccess.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'En vivo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kWebSuccess,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          feedAsync.when(
            loading: () => const _FeedSkeleton(),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No se pudo cargar la actividad',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kWebTextHint,
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
                          color: kWebTextHint.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin actividad reciente',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebTextHint,
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
                    _AnimatedFeedRow(
                      delay: Duration(milliseconds: 60 * i),
                      child: _ActivityRow(item: items[i]),
                    ),
                    if (i < items.length - 1 && i < 7)
                      Divider(
                        height: 1,
                        color: kWebCardBorder.withValues(alpha: 0.5),
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

/// Staggered fade+slide for each feed row.
class _AnimatedFeedRow extends StatefulWidget {
  const _AnimatedFeedRow({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_AnimatedFeedRow> createState() => _AnimatedFeedRowState();
}

class _AnimatedFeedRowState extends State<_AnimatedFeedRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
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

    final (IconData icon, Color color) = switch (item.type) {
      'booking' => (Icons.calendar_today_outlined, kWebSuccess),
      'user' => (Icons.person_add_outlined, kWebInfo),
      'salon' => (Icons.store_outlined, kWebSecondary),
      'cancellation' => (Icons.cancel_outlined, kWebError),
      _ => (Icons.info_outlined, kWebPrimary),
    };

    final timeAgo = _formatTimeAgo(item.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
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
                    color: kWebTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: kWebTextSecondary,
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
              color: kWebTextHint,
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
    final alertsAsync = ref.watch(dashboardAlertsProvider);

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
                  color: kWebWarning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_outlined,
                  size: 18,
                  color: kWebWarning,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Alertas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
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
                      color: kWebError.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alerts.total}',
                      style: const TextStyle(
                        color: kWebError,
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
            loading: () => const _AlertsSkeleton(),
            error: (_, __) => Center(
              child: Text(
                'Error al cargar alertas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextHint,
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
                          Icons.check_circle_outlined,
                          size: 36,
                          color: kWebSuccess.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Todo en orden',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebTextHint,
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
                      icon: Icons.gavel_outlined,
                      label: 'Disputas pendientes',
                      count: alerts.pendingDisputes,
                      color: kWebError,
                    ),
                  if (alerts.unverifiedSalons > 0) ...[
                    if (alerts.pendingDisputes > 0) const SizedBox(height: 12),
                    _AlertRow(
                      icon: Icons.verified_outlined,
                      label: 'Salones sin verificar',
                      count: alerts.unverifiedSalons,
                      color: kWebWarning,
                    ),
                  ],
                  if (alerts.failedPayments > 0) ...[
                    if (alerts.pendingDisputes > 0 ||
                        alerts.unverifiedSalons > 0)
                      const SizedBox(height: 12),
                    _AlertRow(
                      icon: Icons.payment_outlined,
                      label: 'Pagos fallidos',
                      count: alerts.failedPayments,
                      color: kWebError,
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
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 18, color: widget.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: kWebTextPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
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

// ── Skeleton Placeholders ────────────────────────────────────────────────────

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({this.width, this.height = 12, this.borderRadius = 6});
  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kWebCardBorder.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kWebCardBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 120 + (i * 20).toDouble()),
                  const SizedBox(height: 6),
                  _SkeletonBar(width: 80, height: 10),
                ],
              ),
            ),
            const _SkeletonBar(width: 28, height: 10),
          ],
        ),
      )),
    );
  }
}

class _AlertsSkeleton extends StatelessWidget {
  const _AlertsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kWebCardBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _SkeletonBar(width: 140 + (i * 15).toDouble())),
            const _SkeletonBar(width: 24, height: 18, borderRadius: 9),
          ],
        ),
      )),
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
  final isMobile = MediaQuery.sizeOf(context).width < 800;
  return Container(
    height: isMobile ? 210 : 260,
    decoration: BoxDecoration(
      color: kWebSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kWebCardBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: kWebPrimary.withValues(alpha: 0.5),
      ),
    ),
  );
}
