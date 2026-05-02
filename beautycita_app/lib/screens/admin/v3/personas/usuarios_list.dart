// Personas → Usuarios list (v3).
// Search across full_name / username / phone / email. Tap a user to open
// the detail screen with role / suspension / ToS-violation actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_provider.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';
import 'usuario_detail_screen.dart';

class PersonasUsuariosList extends ConsumerStatefulWidget {
  const PersonasUsuariosList({super.key});

  @override
  ConsumerState<PersonasUsuariosList> createState() => _State();
}

class _State extends ConsumerState<PersonasUsuariosList> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _matches(AdminUser u) {
    if (_q.length < 2) return true;
    final hay = '${u.fullName ?? ''} ${u.username} ${u.phone ?? ''}'.toLowerCase();
    return hay.contains(_q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final asyncUsers = ref.watch(adminUsersProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingSM),
          child: TextField(
            controller: _ctrl,
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: 'Buscar nombre / usuario / teléfono',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: asyncUsers.when(
            loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
            error: (e, _) => AdminEmptyState(
              kind: AdminEmptyKind.error,
              body: '$e',
              action: 'Reintentar',
              onAction: () => ref.invalidate(adminUsersProvider),
            ),
            data: (users) {
              final filtered = users.where(_matches).toList();
              if (filtered.isEmpty) {
                return const AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin coincidencias');
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminUsersProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AdminV2Tokens.spacingMD, 0, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _Row(user: filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = (user.fullName?.isNotEmpty == true) ? user.fullName! : (user.username.isNotEmpty ? user.username : '(sin nombre)');
    final hint = [user.username, user.phone ?? ''].where((s) => s.isNotEmpty).join(' · ');
    final role = user.role;
    final phoneVerified = user.phoneVerified;

    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminUsuarioDetailScreen(userId: user.id),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: user.avatarUrl?.isNotEmpty == true ? NetworkImage(user.avatarUrl!) : null,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: user.avatarUrl?.isNotEmpty == true ? null : Icon(Icons.person, color: colors.primary, size: 20),
          ),
          const SizedBox(width: AdminV2Tokens.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (hint.isNotEmpty)
                  Text(hint, style: AdminV2Tokens.muted(context), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (phoneVerified)
            Padding(
              padding: const EdgeInsets.only(right: AdminV2Tokens.spacingXS),
              child: Icon(Icons.verified_user_outlined, size: 14, color: AdminV2Tokens.success(context)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
            ),
            child: Text(role, style: AdminV2Tokens.muted(context).copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
