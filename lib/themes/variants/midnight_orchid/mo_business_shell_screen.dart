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
import 'mo_widgets.dart';

// ─── Midnight Orchid Business Shell ──────────────────────────────────────────
// Rounded everything (nav, cards, chips), Quicksand font, orchid gradient nav
// indicator, soft purple stat cards with orchid border glow.

final _moBizTabProvider = StateProvider<int>((ref) => 0);

class MOBusinessShellScreen extends ConsumerWidget {
  const MOBusinessShellScreen({super.key});

  static const _tabs = <_MOBizTab>[
    _MOBizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _MOBizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _MOBizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _MOBizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _MOBizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _MOBizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _MOBizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _MOBizTab(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final c = MOColors.of(context);

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: c.surface,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: MOFloatingParticles(count: 12, seedOffset: 100),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MOOrchidGlow(
                        child: Icon(Icons.store_outlined,
                            size: 64, color: c.orchidPink),
                      ),
                      const SizedBox(height: AppConstants.paddingLG),
                      Text(
                        'No tienes un negocio registrado',
                        style: GoogleFonts.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'Registra tu salon para empezar.',
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingXL),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: MOOrchidButton(
                          label: 'Registrar Negocio',
                          onTap: () => context.push('/registro'),
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingMD),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Volver',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            color: c.orchidPink,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                c.orchidPink.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return _MOBusinessContent(
          businessName: biz['name'] as String? ?? 'Mi Negocio',
        );
      },
      loading: () => Scaffold(
        backgroundColor: c.surface,
        body: const Center(child: MOLoadingDots()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.surface,
        body: Center(
          child: Text('Error cargando negocio',
              style: GoogleFonts.quicksand(color: c.textSecondary)),
        ),
      ),
    );
  }
}

// ─── Content scaffold ────────────────────────────────────────────────────────

class _MOBusinessContent extends ConsumerWidget {
  final String businessName;
  const _MOBusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_moBizTabProvider);
    final c = MOColors.of(context);
    final safeTab =
        selectedTab.clamp(0, MOBusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        title: MOGradientText(
          text: businessName,
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: c.orchidPurple),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: c.orchidPurple.withValues(alpha: 0.6), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _MOBusinessDrawer(
        tabs: MOBusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(_moBizTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _MODashboardTab(),
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

// ─── Orchid Dashboard Tab ────────────────────────────────────────────────────

class _MODashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MOColors.of(context);
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

    return Stack(
      children: [
        // Floating orchid particles background
        const Positioned.fill(
          child: MOFloatingParticles(count: 8, seedOffset: 200),
        ),
        RefreshIndicator(
          color: c.orchidPink,
          backgroundColor: c.card,
          onRefresh: () async {
            ref.invalidate(businessStatsProvider);
            ref.invalidate(currentBusinessProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              // Stats grid
              statsAsync.when(
                data: (stats) => _MOStatsGrid(stats: stats, ext: ext),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: MOLoadingDots()),
                ),
                error: (e, _) => MOGlowCard(
                  child: Text('Error cargando estadisticas',
                      style: GoogleFonts.quicksand(color: c.orchidPink)),
                ),
              ),

              const SizedBox(height: AppConstants.paddingLG),
              const MOOrchidDivider(),
              const SizedBox(height: AppConstants.paddingSM),

              // Section header
              MOGradientText(
                text: 'Citas de Hoy',
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),

              todayAppts.when(
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return MOGlowCard(
                      borderRadius: 24,
                      padding:
                          const EdgeInsets.all(AppConstants.paddingXL),
                      child: Column(
                        children: [
                          Icon(Icons.event_available_rounded,
                              size: 48,
                              color:
                                  c.orchidPurple.withValues(alpha: 0.5)),
                          const SizedBox(height: AppConstants.paddingSM),
                          Text(
                            'No hay citas para hoy',
                            style: GoogleFonts.quicksand(
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
                      return _MOAppointmentCard(
                          appointment: appt, ext: ext);
                    }).toList(),
                  );
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: MOLoadingDots()),
                ),
                error: (e, _) => Text('Error: $e',
                    style:
                        GoogleFonts.quicksand(color: c.orchidPink)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Orchid Stats Grid ───────────────────────────────────────────────────────

class _MOStatsGrid extends StatelessWidget {
  final BusinessStats stats;
  final BCThemeExtension ext;
  const _MOStatsGrid({required this.stats, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _MOStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Hoy',
          value: '${stats.appointmentsToday}',
          accentColor: c.orchidPink,
        ),
        _MOStatCard(
          icon: Icons.date_range_rounded,
          label: 'Esta Semana',
          value: '${stats.appointmentsWeek}',
          accentColor: c.orchidPurple,
        ),
        _MOStatCard(
          icon: Icons.attach_money_rounded,
          label: 'Ingresos Mes',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          accentColor: c.orchidLight,
        ),
        _MOStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Por Confirmar',
          value: '${stats.pendingConfirmations}',
          accentColor: ext.statusPending,
        ),
        _MOStatCard(
          icon: Icons.star_rounded,
          label: 'Calificacion',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          accentColor: c.orchidLight,
        ),
        _MOStatCard(
          icon: Icons.reviews_rounded,
          label: 'Resenas',
          value: '${stats.totalReviews}',
          accentColor: ext.statusCompleted,
        ),
      ],
    );
  }
}

class _MOStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _MOStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.orchidDeep,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: accentColor),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Appointment card ────────────────────────────────────────────────────────

class _MOAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final BCThemeExtension ext;
  const _MOAppointmentCard(
      {required this.appointment, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
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
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.orchidDeep, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                timeStr,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          title: Text(
            service,
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          subtitle: Text(
            _statusLabel(status),
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            '\$${price.toStringAsFixed(0)}',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.orchidPink,
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

// ─── Orchid Drawer ───────────────────────────────────────────────────────────

class _MOBusinessDrawer extends StatelessWidget {
  final List<_MOBizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MOBusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);

    return Drawer(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
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
                  MOOrchidGlow(
                    child: Icon(Icons.storefront_rounded,
                        size: 32, color: c.orchidPink),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  MOGradientText(
                    text: 'Mi Negocio',
                    style: GoogleFonts.quicksand(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const MOOrchidDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _MODrawerItem(
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

class _MODrawerItem extends StatelessWidget {
  final _MOBizTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _MODrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM, vertical: 2),
      child: Material(
        color: isSelected
            ? c.orchidPurple.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: isSelected
              ? ShaderMask(
                  shaderCallback: (bounds) =>
                      c.orchidGradient.createShader(bounds),
                  child: Icon(tab.icon, color: Colors.white, size: 22),
                )
              : Icon(tab.icon,
                  color: c.textSecondary.withValues(alpha: 0.6),
                  size: 22),
          title: Text(
            tab.label,
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? c.orchidPink : c.text,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─── Tab model ───────────────────────────────────────────────────────────────

class _MOBizTab {
  final IconData icon;
  final String label;
  const _MOBizTab({required this.icon, required this.label});
}
