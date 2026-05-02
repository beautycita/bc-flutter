// Personas → Usuarios → Detail (v3).
//
// Tap a user from PersonasUsuariosList → this screen. Shows the profile,
// saldo, owned salon (if any) and the full action sheet:
//   - Editar rol            (superadmin only)
//   - Suspender / Reactivar (admin+ for suspend, ops_admin+ for reactivate)
//   - Ir al salón           (if owns one — links to the salon detail screen)
//   - RED: Suspender por violación ToS (combined nuke; superadmin only)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_provider.dart';
import '../../../../services/supabase_client.dart';
import '../../../../services/toast_service.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';
import 'salones_detail_screen.dart';

class AdminUsuarioDetailScreen extends ConsumerStatefulWidget {
  const AdminUsuarioDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<AdminUsuarioDetailScreen> createState() =>
      _AdminUsuarioDetailScreenState();
}

class _AdminUsuarioDetailScreenState
    extends ConsumerState<AdminUsuarioDetailScreen> {
  Future<Map<String, dynamic>>? _profileFuture;
  Future<Map<String, dynamic>?>? _ownedBusinessFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _ownedBusinessFuture = _loadOwnedBusiness();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final res = await SupabaseClientService.client
        .rpc('admin_get_user_full_profile', params: {'p_user_id': widget.userId});
    if (res is Map<String, dynamic>) return res;
    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    throw Exception('Usuario no encontrado');
  }

  Future<Map<String, dynamic>?> _loadOwnedBusiness() async {
    final res = await SupabaseClientService.client
        .from('businesses')
        .select(
            'id, name, slug, is_active, suspended_at, suspended_reason, suspension_kind, on_hold')
        .eq('owner_id', widget.userId)
        .maybeSingle();
    return res;
  }

  void _refresh() {
    setState(() {
      _profileFuture = _loadProfile();
      _ownedBusinessFuture = _loadOwnedBusiness();
    });
  }

  @override
  Widget build(BuildContext context) {
    final myRole = ref.watch(userRoleProvider).valueOrNull ?? 'customer';
    final isSuperadmin = myRole == 'superadmin';
    final isOpsAdmin = myRole == 'ops_admin' || myRole == 'admin' || isSuperadmin;
    final isAdminPlus = myRole == 'admin' || isSuperadmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuario')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const AdminEmptyState(kind: AdminEmptyKind.loading);
          }
          if (snap.hasError) {
            return AdminEmptyState(
              kind: AdminEmptyKind.error,
              body: '${snap.error}',
              action: 'Reintentar',
              onAction: _refresh,
            );
          }
          final p = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
              children: [
                _IdentityCard(profile: p),
                const SizedBox(height: AdminV2Tokens.spacingMD),
                _StatusCard(profile: p),
                const SizedBox(height: AdminV2Tokens.spacingMD),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _ownedBusinessFuture,
                  builder: (context, bsnap) {
                    if (bsnap.connectionState != ConnectionState.done) {
                      return const SizedBox.shrink();
                    }
                    return _OwnedSalonCard(
                      business: bsnap.data,
                      onTap: bsnap.data == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PersonasSalonesDetailScreen(
                                    businessId: bsnap.data!['id'] as String,
                                  ),
                                ),
                              );
                            },
                    );
                  },
                ),
                const SizedBox(height: AdminV2Tokens.spacingMD),
                _ActionsCard(
                  profile: p,
                  ownedBusinessFuture: _ownedBusinessFuture!,
                  isAdminPlus: isAdminPlus,
                  isOpsAdmin: isOpsAdmin,
                  isSuperadmin: isSuperadmin,
                  onChange: _refresh,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Identity card ────────────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final username = profile['username'] as String? ?? '';
    final fullName = profile['full_name'] as String? ?? '';
    final phone = profile['phone'] as String? ?? '';
    final email = profile['email'] as String? ?? '';
    final avatarUrl = profile['avatar_url'] as String? ?? '';
    final role = profile['role'] as String? ?? 'customer';

    return AdminCard(
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: avatarUrl.isEmpty ? Icon(Icons.person, color: colors.primary, size: 32) : null,
          ),
          const SizedBox(width: AdminV2Tokens.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName.isNotEmpty ? fullName : username,
                    style: AdminV2Tokens.title(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (fullName.isNotEmpty)
                  Text('@$username', style: AdminV2Tokens.muted(context)),
                const SizedBox(height: 4),
                if (phone.isNotEmpty) Text(phone, style: AdminV2Tokens.body(context)),
                if (email.isNotEmpty) Text(email, style: AdminV2Tokens.muted(context)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AdminV2Tokens.spacingSM, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                  ),
                  child: Text(role,
                      style: AdminV2Tokens.muted(context)
                          .copyWith(color: colors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status card ──────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final status = profile['status'] as String? ?? 'active';
    final suspendedAt = profile['suspended_at'] as String?;
    final suspendedReason = profile['suspended_reason'] as String?;
    final kind = profile['suspension_kind'] as String?;
    final saldo = (profile['saldo'] as num?)?.toDouble() ?? 0.0;

    final isSuspended = status == 'suspended';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AdminCard(
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuspended ? Icons.block : Icons.check_circle,
                color: isSuspended ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isSuspended ? 'Suspendido' : 'Activo',
                style: AdminV2Tokens.body(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSuspended ? Colors.red : Colors.green,
                ),
              ),
              if (kind == 'tos_violation') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('ToS',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          if (isSuspended && suspendedReason != null) ...[
            const SizedBox(height: 8),
            Text(suspendedReason, style: AdminV2Tokens.muted(context)),
          ],
          if (isSuspended && suspendedAt != null) ...[
            const SizedBox(height: 4),
            Text('Desde ${suspendedAt.split('T').first}',
                style: AdminV2Tokens.muted(context)),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: colors.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text('Saldo', style: AdminV2Tokens.body(context)),
              const Spacer(),
              Text('\$${saldo.toStringAsFixed(2)}',
                  style: AdminV2Tokens.body(context)
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Owned salon link card ─────────────────────────────────────────────────
class _OwnedSalonCard extends StatelessWidget {
  const _OwnedSalonCard({required this.business, this.onTap});
  final Map<String, dynamic>? business;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (business == null) {
      return AdminCard(
        padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined,
                size: 20, color: Theme.of(context).disabledColor),
            const SizedBox(width: 8),
            Text('Sin salón registrado', style: AdminV2Tokens.muted(context)),
          ],
        ),
      );
    }
    final name = business!['name'] as String? ?? '(sin nombre)';
    final isActive = business!['is_active'] as bool? ?? false;
    final kind = business!['suspension_kind'] as String?;

    return AdminCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(isActive ? Icons.storefront : Icons.block,
            color: isActive ? Colors.green : Colors.red),
        title: Text(name, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isActive
              ? 'Activo'
              : 'Suspendido${kind == 'tos_violation' ? ' (ToS)' : ''}',
          style: AdminV2Tokens.muted(context),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ── Actions card ──────────────────────────────────────────────────────────
class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({
    required this.profile,
    required this.ownedBusinessFuture,
    required this.isAdminPlus,
    required this.isOpsAdmin,
    required this.isSuperadmin,
    required this.onChange,
  });

  final Map<String, dynamic> profile;
  final Future<Map<String, dynamic>?> ownedBusinessFuture;
  final bool isAdminPlus;
  final bool isOpsAdmin;
  final bool isSuperadmin;
  final VoidCallback onChange;

  Future<void> _editRole(BuildContext context) async {
    final current = profile['role'] as String? ?? 'customer';
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Cambiar rol',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              for (final r in const [
                'customer',
                'stylist',
                'rp',
                'ops_admin',
                'admin',
                'superadmin'
              ])
                ListTile(
                  title: Text(r),
                  trailing: r == current
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == current) return;
    try {
      await SupabaseClientService.client
          .from('profiles')
          .update({'role': picked}).eq('id', profile['id'] as String);
      if (!context.mounted) return;
      ToastService.showSuccess('Rol actualizado a $picked');
      onChange();
    } catch (e) {
      if (!context.mounted) return;
      ToastService.showError('Error: $e');
    }
  }

  Future<void> _suspendUser(BuildContext context) async {
    final reason = await _promptReason(context, 'Suspender usuario',
        'Razón visible solo para admins (mín. 3 caracteres):');
    if (reason == null) return;
    try {
      await SupabaseClientService.client.rpc('admin_set_user_status', params: {
        'p_user_id': profile['id'],
        'p_status': 'suspended',
        'p_reason': reason,
        'p_kind': 'standard',
      });
      if (!context.mounted) return;
      ToastService.showSuccess('Usuario suspendido');
      onChange();
    } catch (e) {
      if (!context.mounted) return;
      ToastService.showError(_friendlyError(e));
    }
  }

  Future<void> _reactivateUser(BuildContext context) async {
    try {
      await SupabaseClientService.client.rpc('admin_set_user_status', params: {
        'p_user_id': profile['id'],
        'p_status': 'active',
      });
      if (!context.mounted) return;
      ToastService.showSuccess('Usuario reactivado');
      onChange();
    } catch (e) {
      if (!context.mounted) return;
      ToastService.showError(_friendlyError(e));
    }
  }

  Future<void> _suspendSalon(BuildContext context, String businessId) async {
    final reason = await _promptReason(context, 'Suspender salón',
        'Razón visible solo para admins (mín. 3 caracteres):');
    if (reason == null) return;
    try {
      await SupabaseClientService.client.rpc('admin_set_salon_active_v2', params: {
        'p_business_id': businessId,
        'p_active': false,
        'p_reason': reason,
        'p_kind': 'standard',
      });
      if (!context.mounted) return;
      ToastService.showSuccess('Salón suspendido');
      onChange();
    } catch (e) {
      if (!context.mounted) return;
      ToastService.showError(_friendlyError(e));
    }
  }

  Future<void> _restoreSalon(BuildContext context, String businessId) async {
    try {
      await SupabaseClientService.client.rpc('admin_set_salon_active_v2', params: {
        'p_business_id': businessId,
        'p_active': true,
        'p_reason': '',
      });
      if (!context.mounted) return;
      ToastService.showSuccess('Salón reactivado');
      onChange();
    } catch (e) {
      if (!context.mounted) return;
      ToastService.showError(_friendlyError(e));
    }
  }

  Future<void> _tosViolation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspender por violación ToS',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        content: const SingleChildScrollView(
          child: Text(
            'Esta acción es irreversible sin intervención manual:\n\n'
            '• El usuario pierde acceso a la app\n'
            '• Se cancelan todas las citas futuras del salón\n'
            '• Se notifica a cada cliente: "no aplicamos protección al comprador"\n'
            '• Cualquier disputa queda sin protección de BeautyCita\n'
            '• Pagos pendientes se congelan\n\n'
            'El usuario puede solicitar copia/eliminación de datos por canal legal.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final reason = await _promptReason(
        context, 'Razón de la violación', 'Mínimo 10 caracteres. Quedará en el audit log.',
        minLength: 10);
    if (reason == null) return;
    try {
      final res = await SupabaseClientService.client
          .rpc('admin_suspend_for_tos_violation', params: {
        'p_user_id': profile['id'],
        'p_reason': reason,
      });
      if (!context.mounted) return;
      final cancelled = (res is Map ? res['cancelled_appointments'] : 0) ?? 0;
      ToastService.showSuccess('Suspendido. $cancelled citas canceladas.');
      onChange();
    } catch (e) {
      if (!context.mounted) return;
      ToastService.showError(_friendlyError(e));
    }
  }

  Future<String?> _promptReason(BuildContext context, String title, String hint,
      {int minLength = 3}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.length < minLength) return;
                Navigator.pop(ctx, v);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('forbidden')) return 'No tienes permisos para esta acción.';
    if (s.contains('step_up_required')) {
      return 'Re-autenticación requerida (últimos 5 min).';
    }
    if (s.contains('reason_required_min_10')) return 'Razón mínimo 10 caracteres.';
    if (s.contains('reason_required')) return 'La razón es obligatoria.';
    return 'Error: $s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile['status'] as String? ?? 'active';
    final isSuspended = status == 'suspended';

    return AdminCard(
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Acciones', style: AdminV2Tokens.title(context)),
          const SizedBox(height: 12),
          if (isSuperadmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Editar rol'),
              subtitle: Text(profile['role'] as String? ?? '',
                  style: AdminV2Tokens.muted(context)),
              onTap: () => _editRole(context),
            ),
          if (!isSuspended && isAdminPlus)
            ListTile(
              leading: const Icon(Icons.block_outlined, color: Colors.orange),
              title: const Text('Suspender usuario'),
              subtitle: const Text('Bloquea acceso a la app. No toca su salón.'),
              onTap: () => _suspendUser(context),
            ),
          if (isSuspended && isOpsAdmin)
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.green),
              title: const Text('Reactivar usuario'),
              onTap: () => _reactivateUser(context),
            ),
          FutureBuilder<Map<String, dynamic>?>(
            future: ownedBusinessFuture,
            builder: (context, snap) {
              final biz = snap.data;
              if (biz == null) return const SizedBox.shrink();
              final bizActive = biz['is_active'] as bool? ?? false;
              final bizId = biz['id'] as String;
              if (bizActive && isAdminPlus) {
                return ListTile(
                  leading: const Icon(Icons.storefront_outlined, color: Colors.orange),
                  title: const Text('Suspender salón'),
                  subtitle: const Text('No suspende al usuario.'),
                  onTap: () => _suspendSalon(context, bizId),
                );
              }
              if (!bizActive && isOpsAdmin) {
                return ListTile(
                  leading: const Icon(Icons.storefront, color: Colors.green),
                  title: const Text('Reactivar salón'),
                  onTap: () => _restoreSalon(context, bizId),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (isSuperadmin) ...[
            const Divider(height: 24),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM),
              ),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: const Text('Suspender por violación ToS',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Usuario + salón + cancela citas + sin protección al comprador.',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _tosViolation(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
