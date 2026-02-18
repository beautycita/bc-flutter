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
import 'on_widgets.dart';

// ─── Ocean Noir Business Shell ───────────────────────────────────────────────
// Angular bottom nav (ONAngularClipper), Rajdhani font UPPERCASE labels,
// cyan scan-line effects, ONHudFrame brackets around stat panels, monospace
// numbers.

final _onBizTabProvider = StateProvider<int>((ref) => 0);

class ONBusinessShellScreen extends ConsumerWidget {
  const ONBusinessShellScreen({super.key});

  static const _tabs = <_ONBizTab>[
    _ONBizTab(icon: Icons.dashboard_rounded, label: 'INICIO'),
    _ONBizTab(icon: Icons.calendar_month_rounded, label: 'CALENDARIO'),
    _ONBizTab(icon: Icons.design_services_rounded, label: 'SERVICIOS'),
    _ONBizTab(icon: Icons.people_rounded, label: 'EQUIPO'),
    _ONBizTab(icon: Icons.gavel_rounded, label: 'DISPUTAS'),
    _ONBizTab(icon: Icons.qr_code_rounded, label: 'QR WALK-IN'),
    _ONBizTab(icon: Icons.payments_rounded, label: 'PAGOS'),
    _ONBizTab(icon: Icons.settings_rounded, label: 'AJUSTES'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final c = ONColors.of(context);

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: c.surface0,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ONHudFrame(
                    bracketSize: 24,
                    color: c.cyan,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Icon(Icons.store_outlined,
                          size: 52, color: c.cyan),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'SIN NEGOCIO REGISTRADO',
                    style: GoogleFonts.rajdhani(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Registra tu salon para continuar.',
                    style: GoogleFonts.rajdhani(
                      fontSize: 14,
                      color: c.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ONAngularButton(
                      label: 'REGISTRAR NEGOCIO',
                      onTap: () => context.push('/registro'),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      '< VOLVER',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        color: c.cyan,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _ONBusinessContent(
          businessName: biz['name'] as String? ?? 'MI NEGOCIO',
        );
      },
      loading: () => Scaffold(
        backgroundColor: c.surface0,
        body: const Center(child: ONDataDots()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.surface0,
        body: Center(
          child: Text('ERROR // NEGOCIO',
              style: GoogleFonts.rajdhani(
                  color: c.red, letterSpacing: 2.0)),
        ),
      ),
    );
  }
}

// ─── Content scaffold ────────────────────────────────────────────────────────

class _ONBusinessContent extends ConsumerWidget {
  final String businessName;
  const _ONBusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_onBizTabProvider);
    final c = ONColors.of(context);
    final safeTab =
        selectedTab.clamp(0, ONBusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: c.surface0,
      appBar: AppBar(
        backgroundColor: c.surface1,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c.cyan,
                boxShadow: [
                  BoxShadow(
                    color: c.cyan.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              businessName.toUpperCase(),
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.w700,
                color: c.text,
                fontSize: 16,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: c.cyan),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: c.cyan.withValues(alpha: 0.6), size: 22),
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
                  c.cyan.withValues(alpha: 0.0),
                  c.cyan.withValues(alpha: 0.4),
                  c.cyan.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: _ONBusinessDrawer(
        tabs: ONBusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(_onBizTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: [
          _ONDashboardTab(),
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

// ─── HUD Dashboard Tab ──────────────────────────────────────────────────────

class _ONDashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ONColors.of(context);
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
      color: c.cyan,
      backgroundColor: c.surface1,
      onRefresh: () async {
        ref.invalidate(businessStatsProvider);
        ref.invalidate(currentBusinessProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Scan-line effect on top
          ONScanLine(height: 4, color: c.cyan),
          const SizedBox(height: AppConstants.paddingSM),

          // Stats inside HUD frame
          ONHudFrame(
            bracketSize: 18,
            color: c.cyan,
            padding: const EdgeInsets.all(8),
            child: statsAsync.when(
              data: (stats) => _ONStatsGrid(stats: stats, ext: ext),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: ONDataDots()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                child: Text('ERROR // ESTADISTICAS',
                    style: GoogleFonts.rajdhani(
                        color: c.red, letterSpacing: 2.0)),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
          const ONCyanDivider(),
          const SizedBox(height: AppConstants.paddingSM),

          // Section header
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                color: c.cyan,
              ),
              const SizedBox(width: 8),
              Text(
                'CITAS // HOY',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: c.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSM),

          todayAppts.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return ONHudFrame(
                  bracketSize: 14,
                  color: c.cyan.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(AppConstants.paddingXL),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_rounded,
                          size: 48,
                          color: c.cyan.withValues(alpha: 0.3)),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'SIN CITAS HOY',
                        style: GoogleFonts.rajdhani(
                          fontSize: 14,
                          color: c.textMuted,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: appointments.take(5).map((appt) {
                  return _ONAppointmentCard(
                      appointment: appt, ext: ext);
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: ONDataDots()),
            ),
            error: (e, _) => Text('ERROR: $e',
                style: GoogleFonts.rajdhani(
                    color: c.red, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ─── HUD Stats Grid ─────────────────────────────────────────────────────────

class _ONStatsGrid extends StatelessWidget {
  final BusinessStats stats;
  final BCThemeExtension ext;
  const _ONStatsGrid({required this.stats, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _ONStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'HOY',
          value: '${stats.appointmentsToday}',
          accentColor: c.cyan,
        ),
        _ONStatCard(
          icon: Icons.date_range_rounded,
          label: 'SEMANA',
          value: '${stats.appointmentsWeek}',
          accentColor: c.teal,
        ),
        _ONStatCard(
          icon: Icons.attach_money_rounded,
          label: 'INGRESO MES',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          accentColor: c.green,
        ),
        _ONStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'PENDIENTES',
          value: '${stats.pendingConfirmations}',
          accentColor: ext.statusPending,
        ),
        _ONStatCard(
          icon: Icons.star_rounded,
          label: 'RATING',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          accentColor: c.cyan,
        ),
        _ONStatCard(
          icon: Icons.reviews_rounded,
          label: 'RESENAS',
          value: '${stats.totalReviews}',
          accentColor: c.teal,
        ),
      ],
    );
  }
}

class _ONStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _ONStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);

    return ClipPath(
      clipper: const ONAngularClipper(clipSize: 12),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accentColor),
            const Spacer(),
            Text(
              value,
              style: GoogleFontsHelper.monospace(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Appointment card ────────────────────────────────────────────────────────

class _ONAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final BCThemeExtension ext;
  const _ONAppointmentCard(
      {required this.appointment, required this.ext});

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
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
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 10),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  timeStr,
                  style: GoogleFontsHelper.monospace(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            title: Text(
              service.toUpperCase(),
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.text,
                letterSpacing: 1.0,
              ),
            ),
            subtitle: Text(
              _statusLabel(status),
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            trailing: Text(
              '\$${price.toStringAsFixed(0)}',
              style: GoogleFontsHelper.monospace(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.cyan,
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
        return 'PENDIENTE';
      case 'confirmed':
        return 'CONFIRMADA';
      case 'completed':
        return 'COMPLETADA';
      case 'cancelled_customer':
        return 'CANCELADA // CLIENTE';
      case 'cancelled_business':
        return 'CANCELADA // NEGOCIO';
      case 'no_show':
        return 'NO ASISTIO';
      default:
        return status.toUpperCase();
    }
  }
}

// ─── Angular HUD Drawer ─────────────────────────────────────────────────────

class _ONBusinessDrawer extends StatelessWidget {
  final List<_ONBizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ONBusinessDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);

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
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.cyan,
                          boxShadow: [
                            BoxShadow(
                              color: c.cyan.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.storefront_rounded,
                          size: 28, color: c.cyan),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'MI NEGOCIO',
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: 3.0,
                    ),
                  ),
                  Text(
                    'PORTAL // NEGOCIO',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      color: c.textMuted,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const ONCyanDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _ONDrawerItem(
                      tab: tabs[i],
                      isSelected: i == selectedIndex,
                      onTap: () => onSelect(i),
                      index: i,
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

class _ONDrawerItem extends StatelessWidget {
  final _ONBizTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  const _ONDrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);

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
                    color: c.cyan.withValues(alpha: 0.06),
                    border: Border(
                      left: BorderSide(color: c.cyan, width: 2),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Text(
                  index.toString().padLeft(2, '0'),
                  style: GoogleFontsHelper.monospace(
                    fontSize: 10,
                    color: isSelected
                        ? c.cyan
                        : c.textMuted.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  tab.icon,
                  color: isSelected ? c.cyan : c.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  tab.label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? c.cyan : c.textSecondary,
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

class _ONBizTab {
  final IconData icon;
  final String label;
  const _ONBizTab({required this.icon, required this.label});
}
