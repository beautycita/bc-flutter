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

/// Index of the currently selected admin tab.
final adminTabProvider = StateProvider<int>((ref) => 0);

class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key});

  static const _tabs = <_AdminTab>[
    _AdminTab(icon: Icons.tune, label: 'Perfiles de Servicio'),
    _AdminTab(icon: Icons.settings, label: 'Configuración Global'),
    _AdminTab(icon: Icons.account_tree, label: 'Árbol de Categorías'),
    _AdminTab(icon: Icons.schedule, label: 'Reglas de Tiempo'),
    _AdminTab(icon: Icons.rate_review, label: 'Reseñas'),
    _AdminTab(icon: Icons.store, label: 'Salones'),
    _AdminTab(icon: Icons.analytics, label: 'Analítica'),
    _AdminTab(icon: Icons.notifications, label: 'Notificaciones'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
    final selectedTab = ref.watch(adminTabProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
          'Motor de Inteligencia',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
            fontSize: 18,
          ),
        ),
      ),
      drawer: _AdminDrawer(
        selectedIndex: selectedTab,
        onSelect: (index) {
          ref.read(adminTabProvider.notifier).state = index;
          Navigator.of(context).pop(); // close drawer
        },
      ),
      body: IndexedStack(
        index: selectedTab,
        children: List.generate(
          AdminShellScreen._tabs.length,
          (i) => _buildTabContent(i),
        ),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const ServiceProfileEditorScreen();
      case 1:
        return const EngineSettingsEditorScreen();
      case 2:
        return const CategoryTreeScreen();
      case 3:
        return const TimeRulesScreen();
      case 4:
        // Review intelligence — placeholder until keyword config table exists
        return const _PlaceholderTab(index: 4);
      case 5:
        return const SalonManagementScreen();
      case 6:
        return const AnalyticsScreen();
      case 7:
        return const NotificationTemplatesScreen();
      default:
        return const _PlaceholderTab(index: 0);
    }
  }
}

class _AdminDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _AdminDrawer({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  Icon(Icons.settings,
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
                    'Motor de Inteligencia',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                itemCount: AdminShellScreen._tabs.length,
                itemBuilder: (context, index) {
                  final tab = AdminShellScreen._tabs[index];
                  final isSelected = index == selectedIndex;

                  return ListTile(
                    leading: Icon(
                      tab.icon,
                      color: isSelected
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.5),
                      size: 22,
                    ),
                    title: Text(
                      tab.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? colors.primary
                            : colors.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        colors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                    ),
                    onTap: () => onSelect(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final int index;
  const _PlaceholderTab({required this.index});

  @override
  Widget build(BuildContext context) {
    final tab = AdminShellScreen._tabs[index];
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tab.icon, size: 48, color: colors.primary),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            tab.label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            'Próximamente',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTab {
  final IconData icon;
  final String label;

  const _AdminTab({required this.icon, required this.label});
}
