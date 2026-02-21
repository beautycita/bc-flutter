import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import 'business_calendar_screen.dart';
import 'business_services_screen.dart';
import 'business_staff_screen.dart';
import 'business_disputes_screen.dart';
import 'business_qr_screen.dart';
import 'business_payments_screen.dart';
import 'business_settings_screen.dart';

final businessTabProvider = StateProvider<int>((ref) => 0);

class BusinessShellScreen extends ConsumerWidget {
  const BusinessShellScreen({super.key});

  static const _tabs = <_BizTab>[
    _BizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _BizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _BizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _BizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _BizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _BizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _BizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _BizTab(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final colors = Theme.of(context).colorScheme;

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F3FF),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined,
                      size: 64, color: colors.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'No tienes un negocio registrado',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Registra tu salon para empezar.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: const Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      height: AppConstants.minTouchHeight,
                      child: ElevatedButton(
                        onPressed: () => context.push('/registro'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: Text(
                          'Registrar Negocio',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _BusinessContent(
            businessName: biz['name'] as String? ?? 'Mi Negocio');
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF5F3FF),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFFF5F3FF),
        body: Center(
          child: Text(
            'Error cargando negocio',
            style: GoogleFonts.poppins(color: const Color(0xFF757575)),
          ),
        ),
      ),
    );
  }
}

// -- Content scaffold with rounded AppBar and drawer --

class _BusinessContent extends ConsumerWidget {
  final String businessName;
  const _BusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(businessTabProvider);
    final colors = Theme.of(context).colorScheme;
    final safeTab =
        selectedTab.clamp(0, BusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppConstants.radiusMD),
          ),
        ),
        title: Text(
          businessName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF000000),
          ),
        ),
        iconTheme: IconThemeData(color: colors.primary),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: colors.primary.withValues(alpha: 0.6), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _BusinessDrawer(
        tabs: BusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(businessTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _DashboardTab(),
          const BusinessCalendarScreen(),
          const BusinessServicesScreen(),
          const BusinessStaffScreen(),
          const BusinessDisputesScreen(),
          const BusinessQrScreen(),
          const BusinessPaymentsScreen(),
          const BusinessSettingsScreen(),
        ],
      ),
    );
  }
}

// -- Dashboard Tab with two stat cards + bar chart --

class _DashboardTab extends ConsumerWidget {
  static const _months = [
    'Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(businessStatsProvider);
    final monthlyAsync = ref.watch(businessMonthlyDailyProvider);
    final now = DateTime.now();

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.invalidate(businessStatsProvider);
        ref.invalidate(businessMonthlyDailyProvider);
        ref.invalidate(currentBusinessProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Two large stat cards side-by-side
          statsAsync.when(
            data: (stats) {
              final monthlyData = monthlyAsync.valueOrNull ?? [];
              // Compute monthly total from daily data
              int monthTotal = 0;
              double monthRevenue = 0;
              for (final d in monthlyData) {
                monthTotal += d.count as int;
                monthRevenue += d.revenue;
              }
              // Last 7 days for sparkline
              final todayIdx = now.day - 1;
              final sparkStart = math.max(0, todayIdx - 6);
              final sparkCounts = monthlyData
                  .skip(sparkStart)
                  .take(todayIdx - sparkStart + 1)
                  .map((d) => d.count.toDouble())
                  .toList();
              final sparkRevenue = monthlyData
                  .skip(sparkStart)
                  .take(todayIdx - sparkStart + 1)
                  .map((d) => d.revenue)
                  .toList();

              return Row(
                children: [
                  Expanded(
                    child: _BigStatCard(
                      title: 'Total Citas',
                      subtitle: 'Este mes',
                      value: '$monthTotal',
                      sparkData: sparkCounts,
                      accentColor: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSM),
                  Expanded(
                    child: _BigStatCard(
                      title: 'Ingresos Totales',
                      subtitle: 'Este mes',
                      value: '\$${monthRevenue.toStringAsFixed(0)}',
                      sparkData: sparkRevenue,
                      accentColor: const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
              child: Text('Error cargando estadisticas',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Bar chart card
          monthlyAsync.when(
            data: (daily) => _BarChartCard(
              monthName: _months[now.month - 1],
              daily: daily,
              today: now.day,
              onViewMore: () {
                // Switch to calendar tab
                ref.read(businessTabProvider.notifier).state = 1;
              },
            ),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e',
                style: GoogleFonts.nunito(color: colors.error)),
          ),
        ],
      ),
    );
  }
}

// -- Big stat card with sparkline --

class _BigStatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final List<double> sparkData;
  final Color accentColor;

  const _BigStatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.sparkData,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF757575),
              )),
          Text(subtitle,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: const Color(0xFF9E9E9E),
              )),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(value,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF212121),
                    )),
              ),
              if (sparkData.length >= 2)
                SizedBox(
                  width: 60,
                  height: 28,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      data: sparkData,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -- Sparkline painter --

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / effectiveRange) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}

// -- Bar chart card --

class _BarChartCard extends StatelessWidget {
  final String monthName;
  final List<({int day, int count, double revenue})> daily;
  final int today;
  final VoidCallback onViewMore;

  const _BarChartCard({
    required this.monthName,
    required this.daily,
    required this.today,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxCount = daily.fold<int>(0, (m, d) => math.max(m, d.count));
    final effectiveMax = math.max(maxCount, 1);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(monthName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF212121),
                        )),
                    Text('Resumen diario de citas',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: const Color(0xFF757575),
                        )),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewMore,
                child: Text('Ver mas',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMD),
          SizedBox(
            height: 140,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in daily)
                    _BarColumn(
                      day: d.day,
                      count: d.count,
                      maxCount: effectiveMax,
                      isToday: d.day == today,
                      isFuture: d.day > today,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final int day;
  final int count;
  final int maxCount;
  final bool isToday;
  final bool isFuture;

  const _BarColumn({
    required this.day,
    required this.count,
    required this.maxCount,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final barMaxHeight = 100.0;
    final barHeight = maxCount > 0
        ? (count / maxCount) * barMaxHeight
        : 0.0;
    final barColor = isFuture
        ? const Color(0xFFE0E0E0)
        : isToday
            ? const Color(0xFF8B5CF6)
            : const Color(0xFF06B6D4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isToday && count > 0)
              Text('$count',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                  )),
            Container(
              height: math.max(barHeight, count > 0 ? 4 : 0),
              width: 18,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('$day',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isToday
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF9E9E9E),
                )),
          ],
        ),
      ),
    );
  }
}

// -- Business Drawer with gold shimmer header, rose divider, rounded tiles --

class _BusinessDrawer extends StatelessWidget {
  final List<_BizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _BusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: const Color(0xFFF5F3FF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppConstants.radiusLG)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront_rounded,
                      size: 32, color: colors.primary),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Mi Negocio',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            // Rose gradient divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.0),
                    colors.primary.withValues(alpha: 0.15),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _DrawerItem(
                      tab: tabs[i],
                      isSelected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final _BizTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM, vertical: 2),
      child: Material(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: ListTile(
          leading: Icon(
            tab.icon,
            color: isSelected
                ? colors.primary
                : const Color(0xFF757575).withValues(alpha: 0.6),
            size: 22,
          ),
          title: Text(
            tab.label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? colors.primary : const Color(0xFF212121),
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// -- Tab model --

class _BizTab {
  final IconData icon;
  final String label;
  const _BizTab({required this.icon, required this.label});
}

// -- Spectrum shimmer text --

class _GoldShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _GoldShimmerText({required this.text, this.style});

  @override
  State<_GoldShimmerText> createState() => _GoldShimmerTextState();
}

class _GoldShimmerTextState extends State<_GoldShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = _controller.value * 3.0 - 1.0;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF00D4AA), // aqua
                Color(0xFF06B6D4), // teal
                Color(0xFF3B82F6), // blue
                Color(0xFF8B5CF6), // purple
                Color(0xFFC026D3), // magenta
                Color(0xFFEC4899), // pink
              ],
              stops: [
                (shimmerOffset - 0.3).clamp(0.0, 1.0),
                (shimmerOffset - 0.1).clamp(0.0, 1.0),
                shimmerOffset.clamp(0.0, 1.0),
                (shimmerOffset + 0.1).clamp(0.0, 1.0),
                (shimmerOffset + 0.3).clamp(0.0, 1.0),
                (shimmerOffset + 0.5).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: (widget.style ?? const TextStyle()).copyWith(
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
