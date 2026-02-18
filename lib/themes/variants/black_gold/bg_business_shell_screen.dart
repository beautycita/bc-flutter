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
import 'bg_widgets.dart';

// ─── Black & Gold Business Shell ─────────────────────────────────────────────
// Dark surfaces, gold gradient nav icons + labels, Playfair Display headers,
// BGGoldShimmer on active nav item, gold-bordered stat cards, gold gradient
// revenue KPIs.

final _bgBizTabProvider = StateProvider<int>((ref) => 0);

class BGBusinessShellScreen extends ConsumerWidget {
  const BGBusinessShellScreen({super.key});

  static const _tabs = <_BGBizTab>[
    _BGBizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _BGBizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _BGBizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _BGBizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _BGBizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _BGBizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _BGBizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _BGBizTab(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final c = BGColors.of(context);

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: c.surface0,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        c.goldGradient.createShader(bounds),
                    child: const Icon(Icons.store_outlined,
                        size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'No tienes un negocio registrado',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Registra tu salon para empezar.',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: c.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  BGGoldButton(
                    label: 'REGISTRAR NEGOCIO',
                    onTap: () => context.push('/registro'),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: c.goldMid,
                        decoration: TextDecoration.underline,
                        decorationColor: c.goldMid.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _BGBusinessContent(
          businessName: biz['name'] as String? ?? 'Mi Negocio',
        );
      },
      loading: () => Scaffold(
        backgroundColor: c.surface0,
        body: const Center(child: BGGoldDots()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.surface0,
        body: Center(
          child: Text(
            'Error cargando negocio',
            style: GoogleFonts.lato(color: c.textMuted),
          ),
        ),
      ),
    );
  }
}

// ─── Content scaffold with drawer nav ────────────────────────────────────────

class _BGBusinessContent extends ConsumerWidget {
  final String businessName;
  const _BGBusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_bgBizTabProvider);
    final c = BGColors.of(context);
    final safeTab =
        selectedTab.clamp(0, BGBusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: c.surface0,
      appBar: AppBar(
        backgroundColor: c.surface1,
        elevation: 0,
        title: BGGoldShimmer(
          child: Text(
            businessName,
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: c.goldMid),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: c.goldMid.withValues(alpha: 0.6), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _BGBusinessDrawer(
        tabs: BGBusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(_bgBizTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _BGDashboardTab(),
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

// ─── Gold-themed Dashboard tab ───────────────────────────────────────────────

class _BGDashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BGColors.of(context);
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
      color: c.goldMid,
      backgroundColor: c.surface1,
      onRefresh: () async {
        ref.invalidate(businessStatsProvider);
        ref.invalidate(currentBusinessProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Stats grid
          statsAsync.when(
            data: (stats) => _BGStatsGrid(stats: stats, ext: ext),
            loading: () => SizedBox(
              height: 200,
              child: Center(child: BGGoldDots()),
            ),
            error: (e, _) => BGLuxuryCard(
              child: Text('Error cargando estadisticas',
                  style: GoogleFonts.lato(color: c.goldMid)),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
          const BGGoldDivider(),
          const SizedBox(height: AppConstants.paddingSM),

          // Section header
          Text(
            'CITAS DE HOY',
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: c.goldMid.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          todayAppts.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return BGLuxuryCard(
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            c.goldGradient.createShader(bounds),
                        child: const Icon(Icons.event_available_rounded,
                            size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'No hay citas para hoy',
                        style: GoogleFonts.lato(
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
                  return _BGAppointmentCard(appointment: appt, ext: ext);
                }).toList(),
              );
            },
            loading: () => SizedBox(
              height: 100,
              child: Center(child: BGGoldDots()),
            ),
            error: (e, _) => Text('Error: $e',
                style: GoogleFonts.lato(color: c.goldMid)),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid (gold-bordered cards, gold gradient revenue KPIs) ────────────

class _BGStatsGrid extends StatelessWidget {
  final BusinessStats stats;
  final BCThemeExtension ext;
  const _BGStatsGrid({required this.stats, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _BGStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Hoy',
          value: '${stats.appointmentsToday}',
          accentColor: c.goldMid,
          isRevenue: false,
        ),
        _BGStatCard(
          icon: Icons.date_range_rounded,
          label: 'Esta Semana',
          value: '${stats.appointmentsWeek}',
          accentColor: ext.infoColor,
          isRevenue: false,
        ),
        _BGStatCard(
          icon: Icons.attach_money_rounded,
          label: 'Ingresos Mes',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          accentColor: c.goldLight,
          isRevenue: true,
        ),
        _BGStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Por Confirmar',
          value: '${stats.pendingConfirmations}',
          accentColor: ext.statusPending,
          isRevenue: false,
        ),
        _BGStatCard(
          icon: Icons.star_rounded,
          label: 'Calificacion',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          accentColor: c.goldLight,
          isRevenue: false,
        ),
        _BGStatCard(
          icon: Icons.reviews_rounded,
          label: 'Resenas',
          value: '${stats.totalReviews}',
          accentColor: ext.statusCompleted,
          isRevenue: false,
        ),
      ],
    );
  }
}

class _BGStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final bool isRevenue;

  const _BGStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.isRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: c.goldMid.withValues(alpha: 0.20),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => c.goldGradient.createShader(bounds),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const Spacer(),
          isRevenue
              ? ShaderMask(
                  shaderCallback: (bounds) =>
                      c.goldGradient.createShader(bounds),
                  child: Text(
                    value,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Appointment card (gold status accents) ──────────────────────────────────

class _BGAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final BCThemeExtension ext;
  const _BGAppointmentCard(
      {required this.appointment, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
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
    final statusLabel = _statusLabel(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: c.goldMid.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              border: Border.all(
                color: c.goldMid.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                timeStr,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          title: Text(
            service,
            style: GoogleFonts.playfairDisplay(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          subtitle: Text(
            statusLabel,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: ShaderMask(
            shaderCallback: (bounds) => c.goldGradient.createShader(bounds),
            child: Text(
              '\$${price.toStringAsFixed(0)}',
              style: GoogleFonts.playfairDisplay(
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

// ─── Gold drawer navigation ──────────────────────────────────────────────────

class _BGBusinessDrawer extends StatelessWidget {
  final List<_BGBizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _BGBusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);

    return Drawer(
      backgroundColor: c.surface1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        c.goldGradient.createShader(bounds),
                    child: const Icon(Icons.storefront_rounded,
                        size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  BGGoldShimmer(
                    child: Text(
                      'Mi Negocio',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const BGGoldDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _BGDrawerItem(
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

class _BGDrawerItem extends StatelessWidget {
  final _BGBizTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _BGDrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);

    return ListTile(
      leading: isSelected
          ? ShaderMask(
              shaderCallback: (bounds) =>
                  c.goldGradient.createShader(bounds),
              child: Icon(tab.icon, color: Colors.white, size: 22),
            )
          : Icon(tab.icon,
              color: c.textMuted.withValues(alpha: 0.6), size: 22),
      title: isSelected
          ? BGGoldShimmer(
              child: Text(
                tab.label,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : Text(
              tab.label,
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: c.textSecondary,
              ),
            ),
      selected: isSelected,
      selectedTileColor: c.goldMid.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      onTap: onTap,
    );
  }
}

// ─── Tab model ───────────────────────────────────────────────────────────────

class _BGBizTab {
  final IconData icon;
  final String label;
  const _BGBizTab({required this.icon, required this.label});
}
