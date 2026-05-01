import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../providers/feature_toggle_provider.dart';
// currentStaffPositionProvider lives in business_provider.dart
import '../../providers/business_chat_provider.dart';
import 'business_chat_list_screen.dart';
import 'business_clients_screen.dart';
import 'business_dashboard_screen.dart';
import 'business_calendar_screen.dart';
import 'business_services_screen.dart';
import 'business_staff_screen.dart';
import 'business_disputes_screen.dart';
import 'business_marketing_screen.dart';
import 'business_qr_screen.dart';
import 'business_payments_screen.dart';
import 'business_settings_screen.dart';
import 'business_staff_analytics_screen.dart';
import 'business_gift_cards_screen.dart';
import 'orders_screen.dart';
import 'pos_management_screen.dart';
import '../../widgets/lobby_music_pill.dart';

final businessTabProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Position-based tab permission matrix
// ---------------------------------------------------------------------------

/// Which tab labels are visible for each staff position.
/// Owners bypass this entirely and see all tabs.
const _positionTabAllowlist = <String, Set<String>>{
  // Manager: everything except SAT Retenciones is handled via feature toggles;
  // here we simply give full access — future billing/SAT tabs can be added
  // to a denylist when those screens are built.
  'manager': {
    'Inicio',
    'Calendario',
    'Rendimiento',
    'Servicios',
    'Equipo',
    'Clientes',
    'Disputas',
    'Marketing',
    'QR Walk-in',
    'Pagos',
    'Regalos',
    'Pedidos',
    'Tienda',
    'Ajustes',
  },
  'receptionist': {
    'Inicio',
    'Calendario',
    'Clientes',
    'QR Walk-in',
    'Pagos',
  },
  // Stylists (apprentices) and assistants do NOT access the business panel.
  // They receive monthly email reports instead.
  'stylist': <String>{},
  'assistant': <String>{},
};

class BusinessShellScreen extends ConsumerWidget {
  const BusinessShellScreen({super.key});

  /// Core tabs (always visible to owners; filtered for other positions).
  static const _coreTabs = <_BizTab>[
    _BizTab(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _BizTab(icon: Icons.calendar_month_rounded, label: 'Calendario'),
    _BizTab(icon: Icons.analytics_rounded, label: 'Rendimiento'),
    _BizTab(icon: Icons.design_services_rounded, label: 'Servicios'),
    _BizTab(icon: Icons.people_rounded, label: 'Equipo'),
    _BizTab(icon: Icons.contacts_rounded, label: 'Clientes'),
    _BizTab(icon: Icons.forum_rounded, label: 'Bandeja'),
    _BizTab(icon: Icons.gavel_rounded, label: 'Disputas'),
    _BizTab(icon: Icons.campaign_rounded, label: 'Marketing'),
    _BizTab(icon: Icons.qr_code_rounded, label: 'QR Walk-in'),
    _BizTab(icon: Icons.payments_rounded, label: 'Pagos'),
    _BizTab(icon: Icons.card_giftcard_rounded, label: 'Regalos'),
  ];

  /// POS-gated tabs (only when enable_pos is on).
  static const _posTabs = <_BizTab>[
    _BizTab(icon: Icons.local_shipping_outlined, label: 'Pedidos'),
    _BizTab(icon: Icons.storefront_outlined, label: 'Tienda'),
  ];

  /// Settings tab (always last).
  static const _settingsTab = _BizTab(icon: Icons.settings_rounded, label: 'Ajustes');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final colors = Theme.of(context).colorScheme;

    return LobbyMusicSuppressor(
      child: bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return Scaffold(
            backgroundColor: colors.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined,
                      size: 64, color: colors.primary.withValues(alpha: 0.5)),
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
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      height: AppConstants.minTouchHeight,
                      child: ElevatedButton(
                        onPressed: () => context.push('/registro'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: Text(
                          'Registrar Negocio',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _BusinessContent(
            businessName: biz['name'] as String? ?? 'Mi Negocio',
            isVerified: biz['is_verified'] as bool? ?? false);
      },
      loading: () => Scaffold(
        backgroundColor: colors.surface,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: colors.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error cargando negocio',
                style: GoogleFonts.poppins(color: colors.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(currentBusinessProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// -- Content scaffold with rounded AppBar and drawer --

class _BusinessContent extends ConsumerWidget {
  final String businessName;
  final bool isVerified;
  const _BusinessContent({required this.businessName, this.isVerified = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(businessTabProvider);
    final toggles = ref.watch(featureTogglesProvider);
    final posEnabled = toggles.isEnabled('enable_pos');
    final colors = Theme.of(context).colorScheme;

    // Resolve the current user's position. Owners always get full access;
    // null position (no staff record) also defaults to full access because
    // the shell already guards against non-owners via currentBusinessProvider.
    final positionAsync = ref.watch(currentStaffPositionProvider);
    final position = positionAsync.valueOrNull; // null = loading or owner

    // Build full tab + children lists (feature-toggle gated).
    // Each entry in allTabChildren must be kept in sync with allTabs.
    final allTabs = <_BizTab>[
      ...BusinessShellScreen._coreTabs,
      if (posEnabled) ...BusinessShellScreen._posTabs,
      BusinessShellScreen._settingsTab,
    ];
    final allChildren = <Widget>[
      const BusinessDashboardScreen(),
      const BusinessCalendarScreen(),
      const BusinessStaffAnalyticsScreen(),
      const BusinessServicesScreen(),
      const BusinessStaffScreen(),
      const BusinessClientsScreen(),
      const BusinessChatListScreen(),
      const BusinessDisputesScreen(),
      const BusinessMarketingScreen(),
      const BusinessQrScreen(),
      const BusinessPaymentsScreen(),
      const BusinessGiftCardsScreen(),
      if (posEnabled) ...[
        const OrdersScreen(),
        const PosManagementScreen(),
      ],
      const BusinessSettingsScreen(),
    ];

    assert(allTabs.length == allChildren.length,
        'Tab/children count mismatch: ${allTabs.length} vs ${allChildren.length}');

    // Apply position-based filtering.
    // 'owner' (or null — the panel guard means null implies owner access)
    // gets the full list. All other positions use the allowlist.
    final allowlist = (position == null || position == 'owner')
        ? null // null = show all
        : _positionTabAllowlist[position];

    // Stylists and assistants don't access the panel — show info screen
    if (allowlist != null && allowlist.isEmpty) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text('BeautyCita', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline_rounded, size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('Panel no disponible',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Como miembro del equipo, recibes un reporte mensual por email con tus servicios, '
                  'comisiones y pagos. Para mas informacion, consulta con la recepcion del salon.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = <_BizTab>[];
    final children = <Widget>[];
    for (var i = 0; i < allTabs.length; i++) {
      if (allowlist == null || allowlist.contains(allTabs[i].label)) {
        tabs.add(allTabs[i]);
        children.add(allChildren[i]);
      }
    }

    final safeTab = selectedTab.clamp(0, tabs.length - 1);
    if (safeTab != selectedTab) {
      // Schedule reset after build to avoid mutating state during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(businessTabProvider.notifier).state = safeTab;
      });
    }

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                businessName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: colors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              Icon(Icons.verified, size: 20, color: colors.primary),
            ],
          ],
        ),
        iconTheme: IconThemeData(color: colors.primary),
        actions: [
          IconButton(
            icon: Icon(Icons.home_rounded,
                color: colors.primary.withValues(alpha: 0.6), size: 22),
            onPressed: () => context.go('/home'),
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      drawer: _BusinessDrawer(
        tabs: tabs,
        selectedIndex: safeTab,
        onSelect: (index) {
          ref.read(businessTabProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
      body: IndexedStack(
        index: safeTab,
        children: children,
      ),
    );
  }
}



// -- Business Drawer with brand shimmer header, rose divider, rounded tiles --

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
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppConstants.radiusLG)),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _DrawerItem(
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

class _DrawerItem extends ConsumerWidget {
  final _BizTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    // Only the inbox tab ("Bandeja") shows an unread badge. Keeps every
    // other drawer row cheap — no extra stream subscriptions.
    final showBadge = tab.label == 'Bandeja';
    final unread = showBadge
        ? ref.watch(businessTotalUnreadProvider).maybeWhen(
              data: (n) => n,
              orElse: () => 0,
            )
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM, vertical: 2),
      child: Material(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: ListTile(
          leading: Icon(
            tab.icon,
            color: isSelected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.6),
            size: 22,
          ),
          title: Text(
            tab.label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? colors.primary : colors.onSurface,
            ),
          ),
          trailing: (showBadge && unread > 0)
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimary,
                    ),
                  ),
                )
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// -- Tab model --

class _BizTab {
  final IconData icon;
  final String label;
  const _BizTab({required this.icon, required this.label});
}

