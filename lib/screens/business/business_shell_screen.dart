import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import 'business_dashboard_screen.dart';
import 'business_calendar_screen.dart';
import 'business_services_screen.dart';
import 'business_staff_screen.dart';
import 'business_disputes_screen.dart';
import 'business_qr_screen.dart';
import 'business_payments_screen.dart';
import 'business_settings_screen.dart';

final businessTabProvider = StateProvider<int>((ref) => 0);

class BusinessShellScreen extends ConsumerWidget {
  const BusinessShellScreen({super.key});

  static const _tabs = <_BizTab>[
    _BizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _BizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _BizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _BizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _BizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _BizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _BizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _BizTab(icon: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final colors = Theme.of(context).colorScheme;

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: colors.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined,
                      size: 64,
                      color: colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(height: AppConstants.paddingLG),
                  Text(
                    'No tienes un negocio registrado',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Registra tu salon para empezar.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  ElevatedButton(
                    onPressed: () => context.push('/registro'),
                    child: const Text('Registrar Negocio'),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        return _BusinessContent(
            businessName: biz['name'] as String? ?? 'Mi Negocio');
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text(
            'Error cargando negocio',
            style: GoogleFonts.poppins(
                color: colors.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

class _BusinessContent extends ConsumerWidget {
  final String businessName;
  const _BusinessContent({required this.businessName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(businessTabProvider);
    final colors = Theme.of(context).colorScheme;
    final safeTab =
        selectedTab.clamp(0, BusinessShellScreen._tabs.length - 1);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          businessName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: colors.onSurface.withValues(alpha: 0.5), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _BusinessDrawer(
        tabs: BusinessShellScreen._tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(businessTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: const [
          BusinessDashboardScreen(),
          BusinessCalendarScreen(),
          BusinessServicesScreen(),
          BusinessStaffScreen(),
          BusinessDisputesScreen(),
          BusinessQrScreen(),
          BusinessPaymentsScreen(),
          BusinessSettingsScreen(),
        ],
      ),
    );
  }
}

class _BusinessDrawer extends StatelessWidget {
  final List<_BizTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _BusinessDrawer({
    required this.tabs,
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
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront_rounded,
                      size: 32, color: colors.primary),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Mi Negocio',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BizTab {
  final IconData icon;
  final String label;
  const _BizTab({required this.icon, required this.label});
}
