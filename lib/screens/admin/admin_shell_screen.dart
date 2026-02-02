import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
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

    return isAdmin.when(
      data: (admin) {
        if (!admin) {
          return Scaffold(
            backgroundColor: BeautyCitaTheme.surfaceCream,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock,
                      size: 64, color: BeautyCitaTheme.textLight),
                  const SizedBox(height: BeautyCitaTheme.spaceLG),
                  Text(
                    'Acceso restringido',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: BeautyCitaTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: BeautyCitaTheme.spaceSM),
                  Text(
                    'No tienes permisos de administrador.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: BeautyCitaTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: BeautyCitaTheme.spaceXL),
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
            style: GoogleFonts.poppins(color: BeautyCitaTheme.textLight),
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

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.surfaceCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: BeautyCitaTheme.textDark),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Motor de Inteligencia',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: BeautyCitaTheme.textDark,
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
    return Drawer(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings,
                      size: 32, color: BeautyCitaTheme.primaryRose),
                  const SizedBox(height: BeautyCitaTheme.spaceSM),
                  Text(
                    'Admin Panel',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: BeautyCitaTheme.textDark,
                    ),
                  ),
                  Text(
                    'Motor de Inteligencia',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: BeautyCitaTheme.textLight,
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
                    vertical: BeautyCitaTheme.spaceSM),
                itemCount: AdminShellScreen._tabs.length,
                itemBuilder: (context, index) {
                  final tab = AdminShellScreen._tabs[index];
                  final isSelected = index == selectedIndex;

                  return ListTile(
                    leading: Icon(
                      tab.icon,
                      color: isSelected
                          ? BeautyCitaTheme.primaryRose
                          : BeautyCitaTheme.textLight,
                      size: 22,
                    ),
                    title: Text(
                      tab.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? BeautyCitaTheme.primaryRose
                            : BeautyCitaTheme.textDark,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        BeautyCitaTheme.primaryRose.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(BeautyCitaTheme.radiusMedium),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tab.icon, size: 48, color: BeautyCitaTheme.primaryRose),
          const SizedBox(height: BeautyCitaTheme.spaceMD),
          Text(
            tab.label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: BeautyCitaTheme.textDark,
            ),
          ),
          const SizedBox(height: BeautyCitaTheme.spaceSM),
          Text(
            'Próximamente',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: BeautyCitaTheme.textLight,
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
