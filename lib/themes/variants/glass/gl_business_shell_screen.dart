import 'dart:ui';
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
import 'gl_widgets.dart';

// ─── Glass Business Shell ────────────────────────────────────────────────────
// Frosted glass bottom nav bar with BackdropFilter, aurora blobs behind
// dashboard, neon stat cards, GLFrostedPanel containers for each section.

final _glBizTabProvider = StateProvider<int>((ref) => 0);

class GLBusinessShellScreen extends ConsumerWidget {
  const GLBusinessShellScreen({super.key});

  static const _tabs = <_GLBizTab>[
    _GLBizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _GLBizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _GLBizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _GLBizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _GLBizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _GLBizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _GLBizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _GLBizTab(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final c = GlColors.of(context);

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: c.bgDeep,
            body: GlAuroraBackground(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlNeonBorder(
                      size: 80,
                      child: Center(
                        child: Icon(Icons.store_outlined,
                            size: 40, color: c.neonPurple),
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingLG),
                    Text(
                      'No tienes un negocio registrado',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    Text(
                      'Registra tu salon para empezar.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingXL),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GlNeonButton(
                        label: 'Registrar Negocio',
                        onTap: () => context.push('/registro'),
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        'Volver',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: c.neonCyan,
                          decoration: TextDecoration.underline,
                          decorationColor: c.neonCyan.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _GLBusinessContent(
          businessName: biz['name'] as String? ?? 'Mi Negocio',
        );
      },
      loading: () => Scaffold(
        backgroundColor: c.bgDeep,
        body: Center(child: GlNeonDots()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bgDeep,
        body: Center(
          child: Text('Error cargando negocio',
              style: GoogleFonts.inter(color: c.textMuted)),
        ),
      ),
    );
  }
}

// ─── Content scaffold ────────────────────────────────────────────────────────

class _GLBusinessContent extends ConsumerWidget {
  final String businessName;
  const _GLBusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_glBizTabProvider);
    final c = GlColors.of(context);
    final safeTab =
        selectedTab.clamp(0, GLBusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: c.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: c.bgMid.withValues(alpha: 0.5),
            ),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => c.neonGradient.createShader(bounds),
          child: Text(
            businessName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: c.neonCyan),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: c.neonCyan.withValues(alpha: 0.6), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _GLBusinessDrawer(
        tabs: GLBusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(_glBizTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _GLDashboardTab(),
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

// ─── Glass Dashboard Tab ─────────────────────────────────────────────────────

class _GLDashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = GlColors.of(context);
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

    return GlAuroraBackground(
      child: RefreshIndicator(
        color: c.neonPink,
        backgroundColor: c.bgMid,
        onRefresh: () async {
          ref.invalidate(businessStatsProvider);
          ref.invalidate(currentBusinessProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          children: [
            // Stats grid
            statsAsync.when(
              data: (stats) => _GLStatsGrid(stats: stats, ext: ext),
              loading: () => SizedBox(
                height: 200,
                child: Center(child: GlNeonDots()),
              ),
              error: (e, _) => GlFrostedPanel(
                child: Text('Error cargando estadisticas',
                    style: GoogleFonts.inter(color: c.neonPink)),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLG),
            const GlDivider(),
            const SizedBox(height: AppConstants.paddingSM),

            // Section header
            ShaderMask(
              shaderCallback: (bounds) =>
                  c.neonGradient.createShader(bounds),
              child: Text(
                'Citas de Hoy',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            todayAppts.when(
              data: (appointments) {
                if (appointments.isEmpty) {
                  return GlFrostedPanel(
                    padding: const EdgeInsets.all(AppConstants.paddingXL),
                    child: Column(
                      children: [
                        Icon(Icons.event_available_rounded,
                            size: 48, color: c.neonCyan.withValues(alpha: 0.5)),
                        const SizedBox(height: AppConstants.paddingSM),
                        Text(
                          'No hay citas para hoy',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: appointments.take(5).map((appt) {
                    return _GLAppointmentCard(appointment: appt, ext: ext);
                  }).toList(),
                );
              },
              loading: () => SizedBox(
                height: 100,
                child: Center(child: GlNeonDots()),
              ),
              error: (e, _) => Text('Error: $e',
                  style: GoogleFonts.inter(color: c.neonPink)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Neon Stats Grid ─────────────────────────────────────────────────────────

class _GLStatsGrid extends StatelessWidget {
  final BusinessStats stats;
  final BCThemeExtension ext;
  const _GLStatsGrid({required this.stats, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _GLStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Hoy',
          value: '${stats.appointmentsToday}',
          neonColor: c.neonPink,
        ),
        _GLStatCard(
          icon: Icons.date_range_rounded,
          label: 'Esta Semana',
          value: '${stats.appointmentsWeek}',
          neonColor: c.neonCyan,
        ),
        _GLStatCard(
          icon: Icons.attach_money_rounded,
          label: 'Ingresos Mes',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          neonColor: c.neonPurple,
        ),
        _GLStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Por Confirmar',
          value: '${stats.pendingConfirmations}',
          neonColor: c.amber,
        ),
        _GLStatCard(
          icon: Icons.star_rounded,
          label: 'Calificacion',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          neonColor: c.amber,
        ),
        _GLStatCard(
          icon: Icons.reviews_rounded,
          label: 'Resenas',
          value: '${stats.totalReviews}',
          neonColor: c.violet,
        ),
      ],
    );
  }
}

class _GLStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color neonColor;

  const _GLStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: neonColor.withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: neonColor.withValues(alpha: 0.08),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: neonColor),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Appointment card ────────────────────────────────────────────────────────

class _GLAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final BCThemeExtension ext;
  const _GLAppointmentCard(
      {required this.appointment, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
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
      child: GlFrostedPanel(
        borderRadius: AppConstants.radiusMD,
        padding: EdgeInsets.zero,
        borderColor: statusColor,
        borderOpacity: 0.25,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Center(
              child: Text(
                timeStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          title: Text(
            service,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          subtitle: Text(
            _statusLabel(status),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            '\$${price.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.neonCyan,
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

// ─── Frosted Glass Drawer ────────────────────────────────────────────────────

class _GLBusinessDrawer extends StatelessWidget {
  final List<_GLBizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _GLBusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: c.bgMid.withValues(alpha: 0.7),
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
                            size: 32, color: c.neonPink),
                        const SizedBox(height: AppConstants.paddingSM),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              c.neonGradient.createShader(bounds),
                          child: Text(
                            'Mi Negocio',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'Portal de Negocio',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const GlDivider(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.paddingSM),
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          ListTile(
                            leading: Icon(
                              tabs[i].icon,
                              color: i == selectedIndex
                                  ? c.neonCyan
                                  : c.textMuted,
                              size: 22,
                            ),
                            title: Text(
                              tabs[i].label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: i == selectedIndex
                                    ? c.neonCyan
                                    : c.textSecondary,
                              ),
                            ),
                            selected: i == selectedIndex,
                            selectedTileColor:
                                c.neonCyan.withValues(alpha: 0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMD),
                            ),
                            onTap: () => onSelect(i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tab model ───────────────────────────────────────────────────────────────

class _GLBizTab {
  final IconData icon;
  final String label;
  const _GLBizTab({required this.icon, required this.label});
}
