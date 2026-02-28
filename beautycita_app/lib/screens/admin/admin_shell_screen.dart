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
import 'admin_salones_screen.dart';
import 'admin_pipeline_screen.dart';
import 'analytics_screen.dart';
import 'notification_templates_screen.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'disputes_screen.dart';
import 'applications_screen.dart';
import 'bookings_screen.dart';
import 'feature_toggles_screen.dart';
import 'reviews_screen.dart';
import 'admin_chat_screen.dart';

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
    _AdminTab(icon: Icons.rocket_launch_rounded, label: 'Pipeline', section: 'Gestion'),
    _AdminTab(icon: Icons.chat_rounded, label: 'Chat', section: 'Gestion'),
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
            backgroundColor: const Color(0xFFF5F3FF),
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
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'No tienes permisos de administrador.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: const Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
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
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF5F3FF),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: const Color(0xFFF5F3FF),
        body: Center(
          child: Text(
            'Error verificando permisos',
            style: GoogleFonts.poppins(color: const Color(0xFF757575)),
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

    final safeTab = selectedTab.clamp(0, allTabs.isEmpty ? 0 : allTabs.length - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
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
            color: const Color(0xFF000000),
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
        return const AdminSalonesScreen();
      case 'Analitica':
        return const AnalyticsScreen();
      case 'Resenas':
        return const ReviewsScreen();
      case 'Pipeline':
        return const AdminPipelineScreen();
      case 'Chat':
        return const AdminChatScreen();
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

// -- Admin Drawer: gold shimmer header, section headers, rose-styled tiles --

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
      backgroundColor: const Color(0xFFF5F3FF),
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
                      color: const Color(0xFF000000),
                    ),
                  ),
                  Text(
                    'BeautyCita',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: const Color(0xFF757575),
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
                                  : const Color(0xFF757575).withValues(alpha: 0.6),
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
                                    : const Color(0xFF212121),
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
          Icon(icon, size: 48, color: colors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF212121),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            subtitle,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: const Color(0xFF757575),
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

// -- Spectrum shimmer text --

class _GoldShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _GoldShimmerText({required this.text, this.style});

  @override
  State<_GoldShimmerText> createState() => _GoldShimmerTextState();
}

class _GoldShimmerTextState extends State<_GoldShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = _controller.value * 3.0 - 1.0;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF00D4AA), // aqua
                Color(0xFF06B6D4), // teal
                Color(0xFF3B82F6), // blue
                Color(0xFF8B5CF6), // purple
                Color(0xFFC026D3), // magenta
                Color(0xFFEC4899), // pink
              ],
              stops: [
                (shimmerOffset - 0.3).clamp(0.0, 1.0),
                (shimmerOffset - 0.1).clamp(0.0, 1.0),
                shimmerOffset.clamp(0.0, 1.0),
                (shimmerOffset + 0.1).clamp(0.0, 1.0),
                (shimmerOffset + 0.3).clamp(0.0, 1.0),
                (shimmerOffset + 0.5).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: (widget.style ?? const TextStyle()).copyWith(
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
