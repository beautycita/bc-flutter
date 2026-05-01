// Personas → Salones · Detail (admin v3)
//
// Built per spec at docs/plans/admin-rebuild/specs/personas_salones_detail.md.
// Replaces admin_salon_detail_screen.dart (2292 lines) and consolidates the
// 4+ scattered mutation paths into 6 SECURITY DEFINER RPCs.
//
// Hard rules followed:
//   - No direct .update() / .insert() / .delete() — every mutation routes
//     through an RPC (see migrations/20260501020001_admin_salon_action_rpcs.sql)
//   - Server enforces tier; UI also hides higher-tier actions for clarity
//   - Step-up auth required for: tier change, suspend, reset onboarding
//   - Audit trigger writes to audit_log on every mutation (Phase 0 mig 002)
//   - All visual elements use admin v2 primitives — no per-screen widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/admin_provider.dart';
import '../../../../providers/admin_salon_financial_summary_provider.dart';
import '../../../../services/supabase_client.dart';
import '../../../../services/toast_service.dart';
import '../../../../widgets/admin/v2/action/action_button.dart';
import '../../../../widgets/admin/v2/action/confirm_sheet.dart';
import '../../../../widgets/admin/v2/action/step_up_sheet.dart';
import '../../../../widgets/admin/v2/data_viz/kpi_tile.dart';
import '../../../../widgets/admin/v2/feedback/audit_indicator.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/layout/list_row.dart';
import '../../../../widgets/admin/v2/shell/permission_chip.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class PersonasSalonesDetailScreen extends ConsumerStatefulWidget {
  const PersonasSalonesDetailScreen({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<PersonasSalonesDetailScreen> createState() => _State();
}

class _State extends ConsumerState<PersonasSalonesDetailScreen> {
  bool _busy = false;
  bool _showRawTier = false;

  // ── Mutation runners — every one through an RPC ───────────────────────────

  Future<void> _runRpc({
    required String rpcName,
    required Map<String, dynamic> params,
    required bool requiresStepUp,
    required String stepUpPurpose,
    required String successLabel,
  }) async {
    if (_busy) return;
    if (requiresStepUp) {
      final ok = await AdminStepUpSheet.show(context, purpose: stepUpPurpose);
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseClientService.client.rpc(rpcName, params: params);
      if (!mounted) return;
      ref.invalidate(adminSalonDetailProvider(widget.businessId));
      ref.invalidate(adminSalonFinancialSummaryProvider(widget.businessId));
      AdminAuditIndicator.show(context, label: successLabel);
    } catch (e, stack) {
      if (!mounted) return;
      ToastService.showErrorWithDetails(_friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('forbidden')) return 'Sin permisos para esta acción.';
    if (s.contains('step_up_required')) return 'La sesión expiró — reintenta para volver a confirmar identidad.';
    if (s.contains('reason_required')) return 'Se requiere motivo para suspender.';
    if (s.contains('field_not_allowed')) return 'Ese campo no se puede editar desde aquí.';
    if (s.contains('invalid_clabe')) return 'CLABE debe tener 18 dígitos.';
    if (s.contains('invalid_phone')) return 'Teléfono con formato inválido.';
    if (s.contains('invalid_tier')) return 'Tier inválido (1, 2 o 3).';
    if (s.contains('salon_not_found')) return 'Salón no encontrado.';
    return ToastService.friendlyError(e);
  }

  // ── Specific actions ──────────────────────────────────────────────────────

  Future<void> _setTier(int newTier) => _runRpc(
        rpcName: 'admin_set_salon_tier',
        params: {'p_business_id': widget.businessId, 'p_new_tier': newTier},
        requiresStepUp: true,
        stepUpPurpose: 'Cambiar tier del salón a $newTier.',
        successLabel: 'Tier actualizado',
      );

  Future<void> _suspend() async {
    final reason = await AdminConfirmSheet.show(
      context,
      title: 'Suspender salón',
      body: 'Quedará inactivo y no aparecerá en búsquedas. Necesitamos un motivo para el registro de auditoría.',
      acceptVerb: 'Suspender',
      requireReason: true,
      reasonOptions: const ['Fraude', 'Quejas reiteradas', 'Solicitud del propietario', 'Pendiente verificación', 'Otro'],
      minReasonLength: 3,
      destructive: true,
    );
    if (reason == null) return;
    await _runRpc(
      rpcName: 'admin_set_salon_active',
      params: {'p_business_id': widget.businessId, 'p_active': false, 'p_reason': reason},
      requiresStepUp: true,
      stepUpPurpose: 'Suspender salón.',
      successLabel: 'Salón suspendido',
    );
  }

  Future<void> _unsuspend() => _runRpc(
        rpcName: 'admin_set_salon_active',
        params: {'p_business_id': widget.businessId, 'p_active': true, 'p_reason': ''},
        requiresStepUp: false,
        stepUpPurpose: '',
        successLabel: 'Salón reactivado',
      );

  Future<void> _toggleVerified(bool value) => _runRpc(
        rpcName: 'admin_set_salon_verified',
        params: {'p_business_id': widget.businessId, 'p_verified': value},
        requiresStepUp: false,
        stepUpPurpose: '',
        successLabel: value ? 'Salón verificado' : 'Verificación removida',
      );

  Future<void> _resetOnboarding() async {
    final ok = await AdminConfirmSheet.show(
      context,
      title: 'Reiniciar onboarding',
      body: 'El salón deberá completar onboarding nuevamente (servicios, horario). ¿Continuar?',
      acceptVerb: 'Reiniciar',
      destructive: false,
    );
    if (ok == null) return;
    await _runRpc(
      rpcName: 'admin_reset_salon_onboarding',
      params: {'p_business_id': widget.businessId},
      requiresStepUp: true,
      stepUpPurpose: 'Reiniciar onboarding del salón.',
      successLabel: 'Onboarding reiniciado',
    );
  }

  Future<void> _editField(String field, String label, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AdminV2Tokens.spacingLG,
            right: AdminV2Tokens.spacingLG,
            top: AdminV2Tokens.spacingLG,
            bottom: AdminV2Tokens.spacingLG + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar $label', style: AdminV2Tokens.title(ctx)),
              const SizedBox(height: AdminV2Tokens.spacingMD),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
                ),
              ),
              const SizedBox(height: AdminV2Tokens.spacingLG),
              Row(
                children: [
                  Expanded(
                    child: AdminActionButton(
                      label: 'Cancelar',
                      variant: AdminActionVariant.secondary,
                      onPressed: () => Navigator.of(ctx).pop(null),
                    ),
                  ),
                  const SizedBox(width: AdminV2Tokens.spacingMD),
                  Expanded(
                    child: AdminActionButton(
                      label: 'Guardar',
                      onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    await _runRpc(
      rpcName: 'admin_update_salon_field',
      params: {
        'p_business_id': widget.businessId,
        'p_field': field,
        'p_value': result.isEmpty ? null : result,
      },
      requiresStepUp: false,
      stepUpPurpose: '',
      successLabel: '$label actualizado',
    );
  }

  // ── URL helpers (kept — operator-side, not platform outbound) ─────────────

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ToastService.showWarning('No se puede abrir: $url');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(adminSalonDetailProvider(widget.businessId));
    final tierAsync = ref.watch(currentAdminTierProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('Detalle del salón', style: AdminV2Tokens.title(context)),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const _SkeletonView(),
        error: (e, _) => Center(
          child: AdminEmptyState(
            kind: AdminEmptyKind.error,
            body: '$e',
            action: 'Reintentar',
            onAction: () => ref.invalidate(adminSalonDetailProvider(widget.businessId)),
          ),
        ),
        data: (salon) {
          if (salon == null) {
            return const Center(child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Salón no encontrado'));
          }
          final tier = tierAsync.valueOrNull ?? AdminTier.none;
          if (tier == AdminTier.none) {
            return const Center(child: AdminEmptyState(kind: AdminEmptyKind.noPermission));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminSalonDetailProvider(widget.businessId));
              ref.invalidate(adminSalonFinancialSummaryProvider(widget.businessId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
              children: [
                _HeaderCard(salon: salon, tier: tier, showRawTier: _showRawTier, onLongPressTier: () => setState(() => _showRawTier = !_showRawTier), onTel: _open, onWa: _open),
                _FinancialSummaryCard(businessId: widget.businessId),
                _FieldsCard(salon: salon, tier: tier, busy: _busy, onEdit: _editField),
                _StateCard(salon: salon, tier: tier, busy: _busy, onSuspend: _suspend, onUnsuspend: _unsuspend, onToggleVerified: _toggleVerified),
                _DangerZoneCard(salon: salon, tier: tier, busy: _busy, onSetTier: _setTier, onResetOnboarding: _resetOnboarding),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Card components — each ~50 lines, all use v2 primitives ─────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.salon,
    required this.tier,
    required this.showRawTier,
    required this.onLongPressTier,
    required this.onTel,
    required this.onWa,
  });
  final Map<String, dynamic> salon;
  final AdminTier tier;
  final bool showRawTier;
  final VoidCallback onLongPressTier;
  final void Function(String) onTel;
  final void Function(String) onWa;

  String _onboardingState(Map<String, dynamic> s) {
    final completed = s['onboarding_complete'] == true;
    final stripeCharges = s['stripe_charges_enabled'] == true;
    final stripePayouts = s['stripe_payouts_enabled'] == true;
    if (stripeCharges && stripePayouts && completed) return 'Lista para depósitos';
    if (completed) return 'Reservable';
    return 'Solo descubrimiento';
  }

  List<String> _missing(Map<String, dynamic> s) {
    final missing = <String>[];
    if ((s['rfc'] as String?)?.isNotEmpty != true) missing.add('RFC');
    if ((s['clabe'] as String?)?.isNotEmpty != true) missing.add('CLABE');
    if (s['stripe_charges_enabled'] != true) missing.add('Stripe');
    if (s['id_verification_status'] != 'verified') missing.add('ID');
    if (s['has_services'] != true) missing.add('Servicios');
    if (s['has_schedule'] != true) missing.add('Horario');
    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = (salon['name'] as String?) ?? 'Salón';
    final phone = (salon['phone'] as String?) ?? '';
    final isVerified = salon['is_verified'] == true;
    final isActive = salon['is_active'] == true;
    final tierNum = salon['tier'] as int?;
    final state = _onboardingState(salon);
    final missing = _missing(salon);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(name, style: AdminV2Tokens.title(context), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        if (isVerified) ...[
                          const SizedBox(width: AdminV2Tokens.spacingXS),
                          Icon(Icons.verified, size: 18, color: colors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: AdminV2Tokens.spacingXS),
                    GestureDetector(
                      onLongPress: onLongPressTier,
                      child: Wrap(
                        spacing: AdminV2Tokens.spacingSM,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                            ),
                            child: Text(state, style: AdminV2Tokens.muted(context).copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
                          ),
                          if (showRawTier && tierNum != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
                              decoration: BoxDecoration(
                                color: colors.onSurface.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                              ),
                              child: Text('tier $tierNum', style: AdminV2Tokens.muted(context)),
                            ),
                          if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
                              decoration: BoxDecoration(
                                color: AdminV2Tokens.destructive(context).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                              ),
                              child: Text('Suspendido', style: AdminV2Tokens.muted(context).copyWith(color: AdminV2Tokens.destructive(context), fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: AdminV2Tokens.spacingMD),
            Row(
              children: [
                Expanded(
                  child: AdminActionButton(
                    label: phone,
                    icon: Icons.phone,
                    variant: AdminActionVariant.secondary,
                    dense: true,
                    onPressed: () => onTel('tel:${phone.replaceAll(RegExp(r"\s+"), "")}'),
                  ),
                ),
                const SizedBox(width: AdminV2Tokens.spacingSM),
                AdminActionButton(
                  label: 'WA',
                  icon: Icons.chat,
                  variant: AdminActionVariant.secondary,
                  dense: true,
                  onPressed: () => onWa('https://wa.me/${phone.replaceAll(RegExp(r"[^0-9]"), "")}'),
                ),
              ],
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AdminV2Tokens.spacingMD),
            Text('Qué falta', style: AdminV2Tokens.muted(context)),
            const SizedBox(height: AdminV2Tokens.spacingXS),
            Wrap(
              spacing: AdminV2Tokens.spacingSM,
              runSpacing: AdminV2Tokens.spacingSM,
              children: missing.map((m) => Container(
                padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
                decoration: BoxDecoration(
                  color: AdminV2Tokens.warning(context).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                ),
                child: Text(m, style: AdminV2Tokens.muted(context).copyWith(color: AdminV2Tokens.warning(context), fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialSummaryCard extends ConsumerWidget {
  const _FinancialSummaryCard({required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminSalonFinancialSummaryProvider(businessId));
    return AdminCard(
      title: 'Resumen financiero',
      child: summaryAsync.when(
        loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
        error: (e, _) => AdminEmptyState(kind: AdminEmptyKind.error, body: '$e'),
        data: (summary) {
          if (summary == null) {
            return const AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin datos');
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: AdminKpiTile(label: 'Deuda', value: summary.outstandingDebt.toStringAsFixed(0), unit: 'MXN')),
              Expanded(child: AdminKpiTile(label: 'Ingreso 30d', value: summary.revenue30d.toStringAsFixed(0), unit: 'MXN')),
              Expanded(child: AdminKpiTile(label: 'Citas 30d', value: '${summary.appointmentCount30d}')),
            ],
          );
        },
      ),
    );
  }
}

class _FieldsCard extends StatelessWidget {
  const _FieldsCard({required this.salon, required this.tier, required this.busy, required this.onEdit});
  final Map<String, dynamic> salon;
  final AdminTier tier;
  final bool busy;
  final Future<void> Function(String, String, String?) onEdit;

  bool get _canEditBasic => tier.index >= AdminTier.opsAdmin.index;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: 'Datos',
      child: Column(
        children: [
          AdminListRow(
            label: 'Nombre',
            value: salon['name'] as String?,
            editable: _canEditBasic,
            onEdit: busy ? null : () => onEdit('name', 'Nombre', salon['name'] as String?),
          ),
          AdminListRow(
            label: 'Dirección',
            value: salon['address'] as String?,
            editable: _canEditBasic,
            onEdit: busy ? null : () => onEdit('address', 'Dirección', salon['address'] as String?),
          ),
          AdminListRow(
            label: 'Teléfono',
            value: salon['phone'] as String?,
            editable: _canEditBasic,
            onEdit: busy ? null : () => onEdit('phone', 'Teléfono', salon['phone'] as String?),
          ),
          // RFC is intentionally read-only for everyone (admin + salon).
          // Once verified at onboarding, it doesn't change — fiscal trail.
          AdminListRow(
            label: 'RFC',
            value: salon['rfc'] as String?,
            editable: false,
            trailing: const Padding(
              padding: EdgeInsets.only(left: AdminV2Tokens.spacingSM),
              child: AdminPermissionChip(state: AdminPermissionState.readOnly),
            ),
          ),
          // CLABE is intentionally read-only (BC directive 2026-05-01).
          // Once onboarding completes, the bank account doesn't change.
          // Adding an additional bank account is a future flow that
          // requires matching RFC + beneficiary, not a free-form edit.
          AdminListRow(
            label: 'CLABE',
            value: (salon['clabe'] as String?)?.replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} '),
            editable: false,
            trailing: const Padding(
              padding: EdgeInsets.only(left: AdminV2Tokens.spacingSM),
              child: AdminPermissionChip(state: AdminPermissionState.readOnly),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.salon,
    required this.tier,
    required this.busy,
    required this.onSuspend,
    required this.onUnsuspend,
    required this.onToggleVerified,
  });
  final Map<String, dynamic> salon;
  final AdminTier tier;
  final bool busy;
  final Future<void> Function() onSuspend;
  final Future<void> Function() onUnsuspend;
  final Future<void> Function(bool) onToggleVerified;

  bool get _isAdmin => tier.index >= AdminTier.admin.index;
  bool get _isOpsAdmin => tier.index >= AdminTier.opsAdmin.index;

  @override
  Widget build(BuildContext context) {
    final isActive = salon['is_active'] == true;
    final isVerified = salon['is_verified'] == true;

    return AdminCard(
      title: 'Estado',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(isActive ? 'Activo' : 'Suspendido', style: AdminV2Tokens.body(context))),
              if (isActive && _isAdmin)
                AdminActionButton(
                  label: 'Suspender',
                  variant: AdminActionVariant.destructive,
                  dense: true,
                  requiresStepUp: true,
                  onPressed: busy ? null : onSuspend,
                ),
              if (!isActive && _isOpsAdmin)
                AdminActionButton(
                  label: 'Reactivar',
                  variant: AdminActionVariant.primary,
                  dense: true,
                  onPressed: busy ? null : onUnsuspend,
                ),
            ],
          ),
          const Divider(height: AdminV2Tokens.spacingLG),
          Row(
            children: [
              Expanded(child: Text(isVerified ? 'Verificado' : 'No verificado', style: AdminV2Tokens.body(context))),
              if (_isAdmin)
                Switch(
                  value: isVerified,
                  onChanged: busy ? null : (v) => onToggleVerified(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({
    required this.salon,
    required this.tier,
    required this.busy,
    required this.onSetTier,
    required this.onResetOnboarding,
  });
  final Map<String, dynamic> salon;
  final AdminTier tier;
  final bool busy;
  final Future<void> Function(int) onSetTier;
  final Future<void> Function() onResetOnboarding;

  bool get _isAdmin => tier.index >= AdminTier.admin.index;

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const SizedBox.shrink();
    }
    final currentTier = salon['tier'] as int? ?? 1;

    return AdminCard(
      title: 'Acciones sensibles',
      trailing: const AdminPermissionChip(state: AdminPermissionState.requiresStepUp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cambiar tier', style: AdminV2Tokens.muted(context)),
          const SizedBox(height: AdminV2Tokens.spacingSM),
          Wrap(
            spacing: AdminV2Tokens.spacingSM,
            children: [1, 2, 3].map((t) {
              final selected = currentTier == t;
              return ChoiceChip(
                label: Text('Tier $t'),
                selected: selected,
                onSelected: busy ? null : (_) => onSetTier(t),
              );
            }).toList(),
          ),
          const Divider(height: AdminV2Tokens.spacingLG),
          AdminActionButton(
            label: 'Reiniciar onboarding',
            icon: Icons.restart_alt,
            variant: AdminActionVariant.secondary,
            requiresStepUp: true,
            onPressed: busy ? null : onResetOnboarding,
          ),
        ],
      ),
    );
  }
}

class _SkeletonView extends StatelessWidget {
  const _SkeletonView();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      children: const [
        AdminCardSkeleton(heightHint: 140),
        AdminCardSkeleton(heightHint: 100),
        AdminCardSkeleton(heightHint: 240),
        AdminCardSkeleton(heightHint: 140),
        AdminCardSkeleton(heightHint: 180),
      ],
    );
  }
}
