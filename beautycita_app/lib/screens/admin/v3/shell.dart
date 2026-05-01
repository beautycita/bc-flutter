// AdminShellV3 — the new admin panel.
//
// 5-section bottom-tab navigation. Tier-gated visibility (sections without
// access are HIDDEN, not greyed). Header: section title · global search ·
// role chip. No carryover from v1 — every section is composed of v3 screens
// built against the v2 design system primitives.
//
// Sections by tier:
//   ops_admin+   : Operaciones · Personas
//   admin+       : + Dinero
//   superadmin   : + Motor · Sistema
//
// Sections marked "in_progress" in their _Section.status field are NOT shown
// in the nav until they ship — build-complete rule (no placeholder screens).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_provider.dart';
import '../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../widgets/admin/v2/shell/global_search_sheet.dart';
import '../../../widgets/admin/v2/shell/role_chip.dart';
import '../../../widgets/admin/v2/tokens.dart';
import '../../../widgets/lobby_music_pill.dart';

import 'operaciones/section.dart';
import 'personas/section.dart';
import 'sistema/section.dart';

/// Section index in the bottom nav. Backwards-compat alias `adminTabProvider`
/// kept so existing callers (profile_sections, home_screen) keep compiling.
final adminV3SectionProvider = StateProvider<int>((ref) => 0);
final adminTabProvider = adminV3SectionProvider;

class AdminShellV3 extends ConsumerWidget {
  const AdminShellV3({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(currentAdminTierProvider);
    final colors = Theme.of(context).colorScheme;

    return LobbyMusicSuppressor(
      child: tierAsync.when(
        loading: () => Scaffold(
          backgroundColor: colors.surface,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _accessDenied(context),
        data: (tier) {
          if (tier == AdminTier.none) return _accessDenied(context);
          return _Body(tier: tier);
        },
      ),
    );
  }

  Widget _accessDenied(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: AdminEmptyState(
            kind: AdminEmptyKind.noPermission,
            body: 'No tienes permisos de administrador.',
            action: 'Volver',
            onAction: () => context.go('/home'),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.tier});
  final AdminTier tier;

  static const _sections = <AdminSection>[
    AdminSection.operaciones,
    AdminSection.personas,
    AdminSection.sistema,
    // Dinero / Motor: not in nav until their screens land — build-complete rule.
  ];

  List<AdminSection> _visible() => _sections.where((s) => s.minTier.index <= tier.index).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final sections = _visible();
    if (sections.isEmpty) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: const SafeArea(child: Center(child: AdminEmptyState(kind: AdminEmptyKind.noPermission))),
      );
    }
    final selected = ref.watch(adminV3SectionProvider).clamp(0, sections.length - 1);
    final current = sections[selected];

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
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
            Text(current.label, style: AdminV2Tokens.title(context)),
            const SizedBox(width: AdminV2Tokens.spacingSM),
            const AdminRoleChip(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Búsqueda global',
            onPressed: () => AdminGlobalSearchSheet.show(context),
          ),
        ],
      ),
      body: _SectionBody(section: current),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => ref.read(adminV3SectionProvider.notifier).state = i,
        destinations: [
          for (final s in sections) NavigationDestination(icon: Icon(s.icon), label: s.label),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AdminSection.operaciones => const OperacionesSection(),
      AdminSection.personas => const PersonasSection(),
      AdminSection.sistema => const SistemaSection(),
      AdminSection.dinero => const _NotShipped(label: 'Dinero'),
      AdminSection.motor => const _NotShipped(label: 'Motor'),
    };
  }
}

enum AdminSection {
  operaciones(label: 'Operaciones', icon: Icons.dashboard_customize_outlined, minTier: AdminTier.opsAdmin),
  personas(label: 'Personas', icon: Icons.groups_outlined, minTier: AdminTier.opsAdmin),
  dinero(label: 'Dinero', icon: Icons.payments_outlined, minTier: AdminTier.admin),
  motor(label: 'Motor', icon: Icons.tune, minTier: AdminTier.superadmin),
  sistema(label: 'Sistema', icon: Icons.settings_outlined, minTier: AdminTier.superadmin);

  const AdminSection({required this.label, required this.icon, required this.minTier});
  final String label;
  final IconData icon;
  final AdminTier minTier;
}

class _NotShipped extends StatelessWidget {
  const _NotShipped({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: AdminEmptyState(
        kind: AdminEmptyKind.empty,
        title: '$label — pendiente',
        body: 'Esta sección no se muestra hasta que sus pantallas estén listas.',
      ),
    );
  }
}
