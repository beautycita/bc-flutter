// admin_shell_v2_screen.dart — Phase 1 of the admin redesign (decision #18).
//
// Five-section bottom-tab IA: Operaciones · Personas · Dinero · Motor · Sistema.
// Each section is a thin host that wraps existing screens as sub-tabs so this
// rebuild is a pure relocation — no internal screen rewrites yet (Phase 2+).
//
// Section visibility is gated by tier (hidden, not disabled, for tiers
// without access). Superadmin gets all 5; admin gets 3 (Operaciones / Personas
// / Dinero); ops_admin gets 2 (Operaciones / Personas).
//
// Header: persistent role chip + global search button + outreach jobs banner
// (rendered inside section bodies that benefit from it).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin/global_search_sheet.dart';
import '../../widgets/admin/role_chip.dart';
import '../../widgets/admin/outreach_jobs_banner.dart';
import '../../widgets/lobby_music_pill.dart';

import 'admin_chat_screen.dart';
import 'admin_engine_screen.dart';
import 'admin_executive_dashboard_screen.dart';
import 'admin_intelligence_screen.dart';
import 'admin_outreach_audit_screen.dart';
import 'admin_rp_tracking_screen.dart';
import 'admin_salones_screen.dart';
import 'admin_system_screen.dart';
import 'admin_tax_reports_screen.dart';
import 'bookings_screen.dart';
import 'disputes_screen.dart';
import 'recent_activity_screen.dart';
import 'reviews_screen.dart';
import 'users_screen.dart';

/// Bottom-tab section index.
final adminV2SectionProvider = StateProvider<int>((ref) => 0);

class AdminShellV2Screen extends ConsumerWidget {
  const AdminShellV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(currentAdminTierProvider);
    final colors = Theme.of(context).colorScheme;

    return LobbyMusicSuppressor(
      child: tier.when(
        loading: () => Scaffold(
          backgroundColor: colors.surface,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _accessDenied(context, colors),
        data: (t) {
          if (t == AdminTier.none) return _accessDenied(context, colors);
          return _Body(tier: t);
        },
      ),
    );
  }

  Widget _accessDenied(BuildContext context, ColorScheme colors) => Scaffold(
        backgroundColor: colors.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: colors.primary.withValues(alpha: 0.4)),
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

class _Body extends ConsumerWidget {
  const _Body({required this.tier});
  final AdminTier tier;

  List<_Section> _visibleSections() {
    final all = [
      _Section.operaciones,
      _Section.personas,
      _Section.dinero,
      _Section.motor,
      _Section.sistema,
    ];
    return all.where((s) => s.visibleFor(tier)).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final sections = _visibleSections();
    final selected = ref.watch(adminV2SectionProvider).clamp(0, sections.length - 1);
    final current = sections[selected];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.home_rounded, color: colors.primary, size: 24),
          tooltip: 'Inicio',
          onPressed: () => context.go('/home'),
        ),
        title: Row(
          children: [
            Text(
              current.label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 10),
            const RoleChip(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Búsqueda global',
            onPressed: () => showGlobalSearch(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (current.showOutreachBanner) const OutreachJobsBanner(),
          Expanded(child: current.build(context)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => ref.read(adminV2SectionProvider.notifier).state = i,
        destinations: [
          for (final s in sections)
            NavigationDestination(icon: Icon(s.icon), label: s.label),
        ],
      ),
    );
  }
}

/// One of the five top-level sections. Each owns its own sub-tab structure
/// and routes to existing screens.
class _Section {
  const _Section({
    required this.label,
    required this.icon,
    required this.minTier,
    required this.tabs,
    this.showOutreachBanner = false,
  });

  final String label;
  final IconData icon;
  final AdminTier minTier;
  final List<_SubTab> tabs;
  final bool showOutreachBanner;

  bool visibleFor(AdminTier t) {
    final rank = {
      AdminTier.none: 0,
      AdminTier.opsAdmin: 1,
      AdminTier.admin: 2,
      AdminTier.superadmin: 3,
    };
    return (rank[t] ?? 0) >= (rank[minTier] ?? 999);
  }

  Widget build(BuildContext context) {
    if (tabs.length == 1) return tabs.first.builder(context);
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [for (final t in tabs) Tab(text: t.label)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [for (final t in tabs) t.builder(context)],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section definitions ──────────────────────────────────────────────

  static final operaciones = _Section(
    label: 'Operaciones',
    icon: Icons.dashboard_customize_outlined,
    minTier: AdminTier.opsAdmin,
    showOutreachBanner: true,
    tabs: [
      // Cola subqueues land here in Phase 2; for now the existing surfaces
      // that fit operations live as sub-tabs.
      _SubTab(label: 'Disputas', builder: (_) => const DisputesScreen()),
      _SubTab(label: 'Citas', builder: (_) => const BookingsScreen()),
      _SubTab(label: 'Reseñas', builder: (_) => const ReviewsScreen()),
      _SubTab(label: 'Soporte', builder: (_) => const AdminChatScreen()),
      _SubTab(label: 'Actividad', builder: (_) => const RecentActivityScreen()),
      _SubTab(label: 'Outreach', builder: (_) => const AdminOutreachAuditScreen()),
    ],
  );

  static final personas = _Section(
    label: 'Personas',
    icon: Icons.groups_outlined,
    minTier: AdminTier.opsAdmin,
    tabs: [
      _SubTab(label: 'Usuarios', builder: (_) => const UsersScreen()),
      _SubTab(label: 'Salones', builder: (_) => const AdminSalonesScreen()),
      _SubTab(label: 'RPs', builder: (_) => const AdminRpTrackingScreen()),
      _SubTab(label: 'Insights', builder: (_) => const AdminIntelligenceScreen()),
    ],
  );

  static final dinero = _Section(
    label: 'Dinero',
    icon: Icons.payments_outlined,
    minTier: AdminTier.admin,
    tabs: [
      _SubTab(label: 'Resumen', builder: (_) => const AdminExecutiveDashboardScreen()),
      _SubTab(label: 'SAT', builder: (_) => const AdminTaxReportsScreen()),
    ],
  );

  static final motor = _Section(
    label: 'Motor',
    icon: Icons.tune,
    minTier: AdminTier.superadmin,
    tabs: [_SubTab(label: 'Motor', builder: (_) => const AdminEngineScreen())],
  );

  static final sistema = _Section(
    label: 'Sistema',
    icon: Icons.settings_outlined,
    minTier: AdminTier.superadmin,
    tabs: [_SubTab(label: 'Sistema', builder: (_) => const AdminSystemScreen())],
  );
}

class _SubTab {
  const _SubTab({required this.label, required this.builder});
  final String label;
  final WidgetBuilder builder;
}
