import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import 'service_profile_editor_screen.dart';
import 'engine_settings_editor_screen.dart';
import 'category_tree_screen.dart';
import 'time_rules_screen.dart';
import 'salon_management_screen.dart';
import 'analytics_screen.dart';
import 'notification_templates_screen.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'disputes_screen.dart';
import 'applications_screen.dart';
import 'bookings_screen.dart';
import 'feature_toggles_screen.dart';

/// Index of the currently selected admin tab.
final adminTabProvider = StateProvider<int>((ref) => 0);

class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key});

  /// Tabs visible to admin AND superadmin.
  static const _adminTabs = <_AdminTab>[
    _AdminTab(icon: Icons.dashboard, label: 'Dashboard', section: 'Gestion'),
    _AdminTab(icon: Icons.people, label: 'Usuarios', section: 'Gestion'),
    _AdminTab(icon: Icons.assignment, label: 'Solicitudes', section: 'Gestion'),
    _AdminTab(icon: Icons.calendar_today, label: 'Citas', section: 'Gestion'),
    _AdminTab(icon: Icons.gavel, label: 'Disputas', section: 'Gestion'),
    _AdminTab(icon: Icons.store, label: 'Salones', section: 'Gestion'),
    _AdminTab(icon: Icons.analytics, label: 'Analitica', section: 'Gestion'),
    _AdminTab(icon: Icons.rate_review, label: 'Resenas', section: 'Gestion'),
  ];

  /// Tabs visible ONLY to superadmin — system config.
  static const _superAdminTabs = <_AdminTab>[
    _AdminTab(icon: Icons.tune, label: 'Perfiles de Servicio', section: 'Motor'),
    _AdminTab(icon: Icons.settings, label: 'Configuracion Global', section: 'Motor'),
    _AdminTab(icon: Icons.account_tree, label: 'Arbol de Categorias', section: 'Motor'),
    _AdminTab(icon: Icons.schedule, label: 'Reglas de Tiempo', section: 'Motor'),
    _AdminTab(icon: Icons.notifications, label: 'Notificaciones', section: 'Sistema'),
    _AdminTab(icon: Icons.toggle_on, label: 'Feature Toggles', section: 'Sistema'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final colors = Theme.of(context).colorScheme;

    return isAdmin.when(
      data: (admin) {
        if (!admin) {
          return Scaffold(
            backgroundColor: colors.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock,
                      size: 64, color: colors.onSurface.withValues(alpha: 0.5)),
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
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        return const _AdminContent();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        body: Center(
          child: Text(
            'Error verificando permisos',
            style: GoogleFonts.poppins(
                color: colors.onSurface.withValues(alpha: 0.5)),
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
        error: (_, __) => <_AdminTab>[],
      ),
    ];

    // Clamp selected tab if role changed
    final safeTab = selectedTab.clamp(0, allTabs.isEmpty ? 0 : allTabs.length - 1);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: colors.onSurface, size: 24),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          allTabs.isNotEmpty ? allTabs[safeTab].label : 'Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
            fontSize: 18,
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu, color: colors.onSurface, size: 26),
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
      body: IndexedStack(
        index: safeTab,
        children: List.generate(
          allTabs.length,
          (i) => _buildTabContent(allTabs, i),
        ),
      ),
    );
  }

  Widget _buildTabContent(List<_AdminTab> tabs, int index) {
    if (index >= tabs.length) return const SizedBox.shrink();
    final tab = tabs[index];

    switch (tab.label) {
      // Admin tabs
      case 'Dashboard':
        return const DashboardScreen();
      case 'Usuarios':
        return const UsersScreen();
      case 'Solicitudes':
        return const ApplicationsScreen();
      case 'Citas':
        return const BookingsScreen();
      case 'Disputas':
        return const DisputesScreen();
      case 'Salones':
        return const SalonManagementScreen();
      case 'Analitica':
        return const AnalyticsScreen();
      case 'Resenas':
        return const _PlaceholderTab(
          icon: Icons.rate_review,
          label: 'Inteligencia de Resenas',
          subtitle: 'Proximamente',
        );

      // Superadmin tabs
      case 'Perfiles de Servicio':
        return const ServiceProfileEditorScreen();
      case 'Configuracion Global':
        return const EngineSettingsEditorScreen();
      case 'Arbol de Categorias':
        return const CategoryTreeScreen();
      case 'Reglas de Tiempo':
        return const TimeRulesScreen();
      case 'Notificaciones':
        return const NotificationTemplatesScreen();
      case 'Feature Toggles':
        return const FeatureTogglesScreen();

      default:
        return _PlaceholderTab(
          icon: tab.icon,
          label: tab.label,
          subtitle: 'Proximamente',
        );
    }
  }
}

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Group tabs by section
    final sections = <String, List<int>>{};
    for (var i = 0; i < tabs.length; i++) {
      sections.putIfAbsent(tabs[i].section, () => []).add(i);
    }

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    for (final i in entry.value)
                      ListTile(
                        leading: Icon(
                          tabs[i].icon,
                          color: i == selectedIndex
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.5),
                          size: 22,
                        ),
                        title: Text(
                          tabs[i].label,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == selectedIndex
                                ? colors.primary
                                : colors.onSurface,
                          ),
                        ),
                        selected: i == selectedIndex,
                        selectedTileColor:
                            colors.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMD),
                        ),
                        onTap: () => onSelect(i),
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

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  const _PlaceholderTab({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colors.primary),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            subtitle,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
