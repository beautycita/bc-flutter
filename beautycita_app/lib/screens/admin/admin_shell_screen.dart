import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../providers/feature_toggle_provider.dart';
import 'admin_shell_v2_screen.dart';
import 'admin_salones_screen.dart';
import 'admin_rp_tracking_screen.dart';
import 'admin_tax_reports_screen.dart';
import 'admin_executive_dashboard_screen.dart';
import 'admin_engine_screen.dart';
import 'admin_system_screen.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'disputes_screen.dart';
import 'bookings_screen.dart';
import 'reviews_screen.dart';
import 'admin_chat_screen.dart';
import 'admin_intelligence_screen.dart';
import '../../widgets/admin/outreach_jobs_banner.dart';
import '../../widgets/lobby_music_pill.dart';

/// Index of the currently selected admin tab.
final adminTabProvider = StateProvider<int>((ref) => 0);

class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key});

  /// Tabs visible to admin AND superadmin.
  static const _adminTabs = <_AdminTab>[
    _AdminTab(icon: Icons.dashboard, label: 'Dashboard', section: 'Gestion'),
    _AdminTab(icon: Icons.people, label: 'Usuarios', section: 'Gestion'),
    _AdminTab(icon: Icons.calendar_today, label: 'Citas', section: 'Gestion'),
    _AdminTab(icon: Icons.gavel, label: 'Disputas', section: 'Gestion'),
    _AdminTab(icon: Icons.store, label: 'Salones', section: 'Gestion'),
    _AdminTab(icon: Icons.rate_review, label: 'Resenas', section: 'Gestion'),
    _AdminTab(icon: Icons.chat_rounded, label: 'Chat', section: 'Gestion'),
    _AdminTab(icon: Icons.directions_walk, label: 'RP Tracking', section: 'Gestion'),
    _AdminTab(icon: Icons.receipt_long, label: 'Retenciones SAT', section: 'Finanzas'),
    _AdminTab(icon: Icons.bar_chart, label: 'Executive', section: 'Finanzas'),
    _AdminTab(icon: Icons.psychology_outlined, label: 'Intel', section: 'Intel'),
  ];

  /// Tabs visible ONLY to superadmin — system config.
  static const _superAdminTabs = <_AdminTab>[
    _AdminTab(icon: Icons.tune, label: 'Motor', section: 'Superadmin'),
    _AdminTab(icon: Icons.settings, label: 'Sistema', section: 'Superadmin'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 1 of admin redesign: when admin_shell_v2_enabled is on,
    // delegate to the new 5-section bottom-tab shell. Toggle defaults
    // off; superadmin flips it in Sistema → Toggles to test.
    final toggles = ref.watch(featureTogglesProvider);
    if (toggles.isEnabled('admin_shell_v2_enabled')) {
      return const AdminShellV2Screen();
    }

    final isAdmin = ref.watch(isAdminProvider);
    final colors = Theme.of(context).colorScheme;

    return LobbyMusicSuppressor(
      child: isAdmin.when(
      data: (admin) {
        if (!admin) {
          return Scaffold(
            backgroundColor: colors.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock,
                      size: 64, color: colors.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'Acceso restringido',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'No tienes permisos de administrador.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                      ),
                    ),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        return const _AdminContent();
      },
      loading: () => Scaffold(
        backgroundColor: colors.surface,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: colors.surface,
        body: Center(
          child: Text(
            'Error verificando permisos',
            style: GoogleFonts.poppins(color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ),
      ),
    );
  }
}

class _AdminContent extends ConsumerWidget {
  const _AdminContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final selectedTab = ref.watch(adminTabProvider);
    final colors = Theme.of(context).colorScheme;

    final allTabs = <_AdminTab>[
      ...AdminShellScreen._adminTabs,
      ...isSuperAdmin.when(
        data: (isSA) => isSA ? AdminShellScreen._superAdminTabs : <_AdminTab>[],
        loading: () => <_AdminTab>[],
        error: (_, _) => <_AdminTab>[],
      ),
    ];

    final safeTab = selectedTab.clamp(0, allTabs.isEmpty ? 0 : allTabs.length - 1);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppConstants.radiusMD),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.home_rounded,
              color: colors.primary, size: 24),
          onPressed: () => context.go('/home'),
          tooltip: 'Inicio',
        ),
        title: Text(
          allTabs.isNotEmpty ? allTabs[safeTab].label : 'Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: colors.onSurface,
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu, color: colors.primary, size: 26),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              tooltip: 'Menu',
            ),
          ),
        ],
      ),
      endDrawer: _AdminDrawer(
        tabs: allTabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(adminTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: Column(
        children: [
          // Persistent banner showing active outreach bulk-send jobs across
          // all admin tabs. Hides itself when no jobs are active.
          const OutreachJobsBanner(),
          Expanded(
            child: IndexedStack(
              index: safeTab,
              children: List.generate(
                allTabs.length,
                (i) => _buildTabContent(allTabs, i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<_AdminTab> tabs, int index) {
    if (index >= tabs.length) return const SizedBox.shrink();
    final tab = tabs[index];

    switch (tab.label) {
      case 'Dashboard':
        return const DashboardScreen();
      case 'Usuarios':
        return const UsersScreen();
      case 'Citas':
        return const BookingsScreen();
      case 'Disputas':
        return const DisputesScreen();
      case 'Salones':
        return const AdminSalonesScreen();
      case 'Resenas':
        return const ReviewsScreen();
      case 'Chat':
        return const AdminChatScreen();
      case 'RP Tracking':
        return const AdminRpTrackingScreen();
      case 'Retenciones SAT':
        return const AdminTaxReportsScreen();
      case 'Executive':
        return const AdminExecutiveDashboardScreen();
      case 'Intel':
        return const AdminIntelligenceScreen();
      case 'Motor':
        return const AdminEngineScreen();
      case 'Sistema':
        return const AdminSystemScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

// -- Admin Drawer: brand shimmer header, section headers, rose-styled tiles --

class _AdminDrawer extends StatelessWidget {
  final List<_AdminTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _AdminDrawer({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Group tabs by section
    final sections = <String, List<int>>{};
    for (var i = 0; i < tabs.length; i++) {
      sections.putIfAbsent(tabs[i].section, () => []).add(i);
    }

    return Drawer(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(AppConstants.radiusLG)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings,
                      size: 32, color: colors.primary),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Admin Panel',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'BeautyCita',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.6),
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
            // Nav items grouped by section
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (final entry in sections.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: colors.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    for (final i in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingSM, vertical: 2),
                        child: Material(
                          color: i == selectedIndex
                              ? colors.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                          child: ListTile(
                            leading: Icon(
                              tabs[i].icon,
                              color: i == selectedIndex
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.6),
                              size: 22,
                            ),
                            title: Text(
                              tabs[i].label,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == selectedIndex
                                    ? colors.primary
                                    : colors.onSurface,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMD),
                            ),
                            onTap: () => onSelect(i),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTab {
  final IconData icon;
  final String label;
  final String section;

  const _AdminTab({
    required this.icon,
    required this.label,
    required this.section,
  });
}
