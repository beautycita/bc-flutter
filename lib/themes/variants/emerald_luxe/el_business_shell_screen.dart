import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../providers/business_provider.dart';
import '../../../screens/business/business_calendar_screen.dart';
import '../../../screens/business/business_services_screen.dart';
import '../../../screens/business/business_staff_screen.dart';
import '../../../screens/business/business_disputes_screen.dart';
import '../../../screens/business/business_qr_screen.dart';
import '../../../screens/business/business_payments_screen.dart';
import '../../../screens/business/business_settings_screen.dart';
import 'el_widgets.dart';

// ─── Emerald Luxe Business Shell ─────────────────────────────────────────────
// Art deco bottom nav with diamond separator, Cinzel font, gold+emerald
// gradient stat panels, geometric diamond ornament dividers between sections.

final _elBizTabProvider = StateProvider<int>((ref) => 0);

class ELBusinessShellScreen extends ConsumerWidget {
  const ELBusinessShellScreen({super.key});

  static const _tabs = <_ELBizTab>[
    _ELBizTab(icon: Icons.dashboard_rounded, label: 'INICIO'),
    _ELBizTab(icon: Icons.calendar_month_rounded, label: 'CALENDARIO'),
    _ELBizTab(icon: Icons.design_services_rounded, label: 'SERVICIOS'),
    _ELBizTab(icon: Icons.people_rounded, label: 'EQUIPO'),
    _ELBizTab(icon: Icons.gavel_rounded, label: 'DISPUTAS'),
    _ELBizTab(icon: Icons.qr_code_rounded, label: 'QR WALK-IN'),
    _ELBizTab(icon: Icons.payments_rounded, label: 'PAGOS'),
    _ELBizTab(icon: Icons.settings_rounded, label: 'AJUSTES'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final c = ELColors.of(context);

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: c.bg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ELDecoFrame(
                    cornerSize: 16,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Icon(Icons.store_outlined,
                          size: 52, color: c.gold),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'SIN NEGOCIO',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Registra tu salon para continuar',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ELGeometricButton(
                      label: 'REGISTRAR',
                      onTap: () => context.push('/registro'),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'VOLVER',
                      style: GoogleFonts.cinzel(
                        fontSize: 12,
                        color: c.gold,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _ELBusinessContent(
          businessName: biz['name'] as String? ?? 'Mi Negocio',
        );
      },
      loading: () => Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: ELGeometricDots()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Text('Error cargando negocio',
              style: GoogleFonts.lato(color: c.textSecondary)),
        ),
      ),
    );
  }
}

// ─── Content scaffold ────────────────────────────────────────────────────────

class _ELBusinessContent extends ConsumerWidget {
  final String businessName;
  const _ELBusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_elBizTabProvider);
    final c = ELColors.of(context);
    final safeTab =
        selectedTab.clamp(0, ELBusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Row(
          children: [
            // Diamond accent before title
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.gold,
                  boxShadow: [
                    BoxShadow(
                      color: c.gold.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              businessName.toUpperCase(),
              style: GoogleFonts.cinzel(
                fontWeight: FontWeight.w700,
                color: c.gold,
                fontSize: 14,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: c.gold),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: c.gold.withValues(alpha: 0.5), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.gold.withValues(alpha: 0.0),
                  c.gold.withValues(alpha: 0.3),
                  c.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: _ELBusinessDrawer(
        tabs: ELBusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(_elBizTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _ELDashboardTab(),
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

// ─── Art Deco Dashboard Tab ──────────────────────────────────────────────────

class _ELDashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ELColors.of(context);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final statsAsync = ref.watch(businessStatsProvider);

    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final todayAppts = ref.watch(
      businessAppointmentsProvider((start: todayStart, end: todayEnd)),
    );

    return RefreshIndicator(
      color: c.gold,
      backgroundColor: c.surface,
      onRefresh: () async {
        ref.invalidate(businessStatsProvider);
        ref.invalidate(currentBusinessProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Section header
          const ELDecoSectionHeader(label: 'ESTADISTICAS'),
          const SizedBox(height: AppConstants.paddingSM),

          // Stats grid
          statsAsync.when(
            data: (stats) => _ELStatsGrid(stats: stats, ext: ext),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: ELGeometricDots()),
            ),
            error: (e, _) => ELDecoCard(
              child: Text('Error cargando estadisticas',
                  style: GoogleFonts.lato(color: c.gold)),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Diamond ornament divider
          const ELGoldAccent(),

          const SizedBox(height: AppConstants.paddingSM),

          // Section header
          const ELDecoSectionHeader(label: 'CITAS DE HOY'),
          const SizedBox(height: AppConstants.paddingSM),

          todayAppts.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return ELDecoCard(
                  padding: const EdgeInsets.all(AppConstants.paddingXL),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_rounded,
                          size: 48,
                          color: c.gold.withValues(alpha: 0.3)),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'Sin citas programadas',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: appointments.take(5).map((appt) {
                  return _ELAppointmentCard(
                      appointment: appt, ext: ext);
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: ELGeometricDots()),
            ),
            error: (e, _) => Text('Error: $e',
                style: GoogleFonts.lato(color: c.gold)),
          ),
        ],
      ),
    );
  }
}

// ─── Art Deco Stats Grid ─────────────────────────────────────────────────────

class _ELStatsGrid extends StatelessWidget {
  final BusinessStats stats;
  final BCThemeExtension ext;
  const _ELStatsGrid({required this.stats, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _ELStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'HOY',
          value: '${stats.appointmentsToday}',
          useGoldGradient: false,
          accentColor: c.gold,
        ),
        _ELStatCard(
          icon: Icons.date_range_rounded,
          label: 'SEMANA',
          value: '${stats.appointmentsWeek}',
          useGoldGradient: false,
          accentColor: c.emerald,
        ),
        _ELStatCard(
          icon: Icons.attach_money_rounded,
          label: 'INGRESO MES',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          useGoldGradient: true,
          accentColor: c.gold,
        ),
        _ELStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'PENDIENTES',
          value: '${stats.pendingConfirmations}',
          useGoldGradient: false,
          accentColor: ext.statusPending,
        ),
        _ELStatCard(
          icon: Icons.star_rounded,
          label: 'CALIFICACION',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          useGoldGradient: true,
          accentColor: c.goldLight,
        ),
        _ELStatCard(
          icon: Icons.reviews_rounded,
          label: 'RESENAS',
          value: '${stats.totalReviews}',
          useGoldGradient: false,
          accentColor: c.emerald,
        ),
      ],
    );
  }
}

class _ELStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool useGoldGradient;
  final Color accentColor;

  const _ELStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.useGoldGradient,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(
              color: c.gold.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: accentColor),
              const Spacer(),
              useGoldGradient
                  ? ShaderMask(
                      shaderCallback: (bounds) =>
                          c.goldGradient.createShader(bounds),
                      child: Text(
                        value,
                        style: GoogleFonts.cinzel(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: GoogleFonts.cinzel(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
              Text(
                label,
                style: GoogleFonts.cinzel(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
        // Deco corner ornaments
        Positioned(
          top: -1,
          left: -1,
          child: ELDecoCorner(size: 8),
        ),
        Positioned(
          top: -1,
          right: -1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: ELDecoCorner(size: 8),
          ),
        ),
        Positioned(
          bottom: -1,
          left: -1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(math.pi),
            child: ELDecoCorner(size: 8),
          ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(math.pi),
            child: ELDecoCorner(size: 8),
          ),
        ),
      ],
    );
  }
}

// ─── Appointment card ────────────────────────────────────────────────────────

class _ELAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final BCThemeExtension ext;
  const _ELAppointmentCard(
      {required this.appointment, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    final status = appointment['status'] as String? ?? 'pending';
    final service = appointment['service_name'] as String? ?? 'Servicio';
    final startsAt = appointment['starts_at'] as String?;
    final price = (appointment['price'] as num?)?.toDouble() ?? 0;

    String timeStr = '';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt);
      if (dt != null) {
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: ELDecoCard(
        padding: EdgeInsets.zero,
        cornerLength: 8,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              border: Border.all(
                color: c.gold.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                timeStr,
                style: GoogleFonts.cinzel(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          title: Text(
            service.toUpperCase(),
            style: GoogleFonts.cinzel(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.text,
              letterSpacing: 1.0,
            ),
          ),
          subtitle: Text(
            _statusLabel(status),
            style: GoogleFonts.lato(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: ShaderMask(
            shaderCallback: (bounds) =>
                c.goldGradient.createShader(bounds),
            child: Text(
              '\$${price.toStringAsFixed(0)}',
              style: GoogleFonts.cinzel(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return ext.statusPending;
      case 'confirmed':
        return ext.statusConfirmed;
      case 'completed':
        return ext.statusCompleted;
      case 'cancelled_customer':
      case 'cancelled_business':
        return ext.statusCancelled;
      case 'no_show':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'completed':
        return 'Completada';
      case 'cancelled_customer':
        return 'Cancelada (cliente)';
      case 'cancelled_business':
        return 'Cancelada (negocio)';
      case 'no_show':
        return 'No asistio';
      default:
        return status;
    }
  }
}

// ─── Art Deco Drawer ─────────────────────────────────────────────────────────

class _ELBusinessDrawer extends StatelessWidget {
  final List<_ELBizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ELBusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);

    return Drawer(
      backgroundColor: c.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 28, color: c.gold),
                      const SizedBox(width: 8),
                      // Small diamond separator
                      Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          color: c.gold.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'MI NEGOCIO',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.gold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const ELGoldAccent(showDiamond: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _ELDrawerItem(
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

class _ELDrawerItem extends StatelessWidget {
  final _ELBizTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _ELDrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: isSelected
                ? BoxDecoration(
                    color: c.gold.withValues(alpha: 0.06),
                    border: Border(
                      left: BorderSide(
                        color: c.gold,
                        width: 2,
                      ),
                    ),
                  )
                : null,
            child: Row(
              children: [
                if (isSelected)
                  Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      color: c.gold,
                      margin: const EdgeInsets.only(right: 10),
                    ),
                  ),
                Icon(
                  tab.icon,
                  color: isSelected ? c.gold : c.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  tab.label,
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? c.gold : c.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tab model ───────────────────────────────────────────────────────────────

class _ELBizTab {
  final IconData icon;
  final String label;
  const _ELBizTab({required this.icon, required this.label});
}
