// AdminShellV3 — the new admin panel.
//
// Bottom-tab nav with the daily-driver sections only. Operaciones (work
// queue + outreach) and Personas (user/salon management) are the only ones
// that need to be one tap away. Sistema (toggles + auditoría) lives behind
// the superadmin overflow menu in the header — BC's directive: "the admin
// will never need to access the toggles or the auditor."
//
// Tier-gated visibility:
//   ops_admin / admin / superadmin : Operaciones · Personas
//   admin+ : + (Dinero — hidden until ready)
//   superadmin : + overflow menu with Toggles · Auditoría

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../widgets/admin/v2/shell/global_search_sheet.dart';
import '../../../widgets/admin/v2/shell/role_chip.dart';
import '../../../widgets/admin/v2/tokens.dart';
import '../../../widgets/lobby_music_pill.dart';

import 'operaciones/section.dart';
import 'personas/section.dart';

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
    // Dinero / Motor: not in nav until their screens land — build-complete rule.
    // Sistema (Toggles + Auditoría) lives in the superadmin overflow menu.
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
    final isSuperadmin = tier == AdminTier.superadmin;

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
          if (isSuperadmin)
            PopupMenuButton<_SuperadminAction>(
              tooltip: 'Más',
              icon: const Icon(Icons.more_vert),
              onSelected: (a) => switch (a) {
                _SuperadminAction.toggles => context.push(AppRoutes.adminV3SistemaToggles),
                _SuperadminAction.auditoria => context.push(AppRoutes.adminV3SistemaAuditoria),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _SuperadminAction.toggles,
                  child: ListTile(leading: Icon(Icons.toggle_on_outlined), title: Text('Toggles'), dense: true),
                ),
                PopupMenuItem(
                  value: _SuperadminAction.auditoria,
                  child: ListTile(leading: Icon(Icons.fact_check_outlined), title: Text('Auditoría'), dense: true),
                ),
              ],
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
      AdminSection.dinero => const _NotShipped(label: 'Dinero'),
      AdminSection.motor => const _NotShipped(label: 'Motor'),
    };
  }
}

enum AdminSection {
  operaciones(label: 'Operaciones', icon: Icons.dashboard_customize_outlined, minTier: AdminTier.opsAdmin),
  personas(label: 'Personas', icon: Icons.groups_outlined, minTier: AdminTier.opsAdmin),
  dinero(label: 'Dinero', icon: Icons.payments_outlined, minTier: AdminTier.admin),
  motor(label: 'Motor', icon: Icons.tune, minTier: AdminTier.superadmin);

  const AdminSection({required this.label, required this.icon, required this.minTier});
  final String label;
  final IconData icon;
  final AdminTier minTier;
}

enum _SuperadminAction { toggles, auditoria }

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
