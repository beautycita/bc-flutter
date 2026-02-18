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
import 'cb_widgets.dart';

// ─── Cherry Blossom Business Shell ───────────────────────────────────────────
// Soft floating bottom nav pill, Cormorant Garamond titles, pink-lavender
// gradient accents, rounded 28px stat cards, CBAccentLine separators.

final _cbBizTabProvider = StateProvider<int>((ref) => 0);

class CBBusinessShellScreen extends ConsumerWidget {
  const CBBusinessShellScreen({super.key});

  static const _tabs = <_CBBizTab>[
    _CBBizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _CBBizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _CBBizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _CBBizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _CBBizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _CBBizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _CBBizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _CBBizTab(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final c = CBColors.of(context);

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: c.bg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.pinkLight,
                    ),
                    child: Icon(Icons.store_outlined,
                        size: 40, color: c.pink),
                  ),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'No tienes un negocio registrado',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Registra tu salon para empezar.',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      color: c.textSoft,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: CBSoftButton(
                      label: 'Registrar Negocio',
                      onTap: () => context.push('/registro'),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 14,
                        color: c.pink,
                        decoration: TextDecoration.underline,
                        decorationColor: c.pink.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _CBBusinessContent(
          businessName: biz['name'] as String? ?? 'Mi Negocio',
        );
      },
      loading: () => Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CBLoadingDots()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Text('Error cargando negocio',
              style: GoogleFonts.nunitoSans(color: c.textSoft)),
        ),
      ),
    );
  }
}

// ─── Content scaffold ────────────────────────────────────────────────────────

class _CBBusinessContent extends ConsumerWidget {
  final String businessName;
  const _CBBusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_cbBizTabProvider);
    final c = CBColors.of(context);
    final safeTab =
        selectedTab.clamp(0, CBBusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        title: Text(
          businessName,
          style: GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.w700,
            color: c.text,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: c.pink),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: c.pink.withValues(alpha: 0.5), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _CBBusinessDrawer(
        tabs: CBBusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(_cbBizTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _CBDashboardTab(),
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

// ─── Cherry Blossom Dashboard Tab ────────────────────────────────────────────

class _CBDashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CBColors.of(context);
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
      color: c.pink,
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
            data: (stats) => _CBStatsGrid(stats: stats, ext: ext),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CBLoadingDots()),
            ),
            error: (e, _) => CBWatercolorCard(
              child: Text('Error cargando estadisticas',
                  style: GoogleFonts.nunitoSans(color: c.pink)),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // CBAccentLine separator
          Center(
            child: Row(
              children: [
                const CBAccentLine(width: 60),
                const Spacer(),
                Text(
                  'Citas de Hoy',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                CBAccentLine(width: 60),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          todayAppts.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return CBWatercolorCard(
                  borderRadius: 28,
                  elevated: true,
                  padding: const EdgeInsets.all(AppConstants.paddingXL),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_rounded,
                          size: 48,
                          color: c.pink.withValues(alpha: 0.3)),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'No hay citas para hoy',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          color: c.textSoft,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: appointments.take(5).map((appt) {
                  return _CBAppointmentCard(
                      appointment: appt, ext: ext);
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CBLoadingDots()),
            ),
            error: (e, _) => Text('Error: $e',
                style: GoogleFonts.nunitoSans(color: c.pink)),
          ),
        ],
      ),
    );
  }
}

// ─── Cherry Blossom Stats Grid ───────────────────────────────────────────────

class _CBStatsGrid extends StatelessWidget {
  final BusinessStats stats;
  final BCThemeExtension ext;
  const _CBStatsGrid({required this.stats, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _CBStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Hoy',
          value: '${stats.appointmentsToday}',
          accentColor: c.pink,
        ),
        _CBStatCard(
          icon: Icons.date_range_rounded,
          label: 'Esta Semana',
          value: '${stats.appointmentsWeek}',
          accentColor: c.lavender,
        ),
        _CBStatCard(
          icon: Icons.attach_money_rounded,
          label: 'Ingresos Mes',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          accentColor: c.pink,
        ),
        _CBStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Por Confirmar',
          value: '${stats.pendingConfirmations}',
          accentColor: c.peach,
        ),
        _CBStatCard(
          icon: Icons.star_rounded,
          label: 'Calificacion',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          accentColor: c.peach,
        ),
        _CBStatCard(
          icon: Icons.reviews_rounded,
          label: 'Resenas',
          value: '${stats.totalReviews}',
          accentColor: c.lavender,
        ),
      ],
    );
  }
}

class _CBStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _CBStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: c.pink.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: c.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Appointment card ────────────────────────────────────────────────────────

class _CBAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final BCThemeExtension ext;
  const _CBAppointmentCard(
      {required this.appointment, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
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
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: c.pink.withValues(alpha: 0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: c.pink.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                timeStr,
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          title: Text(
            service,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          subtitle: Text(
            _statusLabel(status),
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            '\$${price.toStringAsFixed(0)}',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.pink,
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

// ─── Cherry Blossom Drawer ───────────────────────────────────────────────────

class _CBBusinessDrawer extends StatelessWidget {
  final List<_CBBizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _CBBusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);

    return Drawer(
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.pinkLight,
                    ),
                    child: Icon(Icons.storefront_rounded,
                        size: 24, color: c.pink),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Mi Negocio',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: c.textSoft,
                    ),
                  ),
                ],
              ),
            ),
            const CBPetalDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _CBDrawerItem(
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

class _CBDrawerItem extends StatelessWidget {
  final _CBBizTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _CBDrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM, vertical: 2),
      child: Material(
        color: isSelected
            ? c.pinkLight
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          leading: Icon(
            tab.icon,
            color: isSelected ? c.pink : c.textSoft.withValues(alpha: 0.6),
            size: 22,
          ),
          title: Text(
            tab.label,
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? c.pink : c.text,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─── Tab model ───────────────────────────────────────────────────────────────

class _CBBizTab {
  final IconData icon;
  final String label;
  const _CBBizTab({required this.icon, required this.label});
}
