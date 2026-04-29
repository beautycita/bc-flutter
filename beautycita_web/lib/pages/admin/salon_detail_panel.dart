import 'dart:convert';

import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/web_theme.dart';
import '../../providers/admin_salons_provider.dart';
import '../../providers/outreach_contact_provider.dart';
import '../../widgets/contact_panel.dart';

/// Detail panel content for a registered salon.
class RegisteredSalonDetailContent extends ConsumerStatefulWidget {
  const RegisteredSalonDetailContent({required this.salon, super.key});

  final RegisteredSalon salon;

  @override
  ConsumerState<RegisteredSalonDetailContent> createState() =>
      _RegisteredSalonDetailContentState();
}

class _RegisteredSalonDetailContentState
    extends ConsumerState<RegisteredSalonDetailContent> {
  bool _togglingVerified = false;
  bool _approvingLicense = false;
  bool _rejectingLicense = false;
  bool _suspendingOrReactivating = false;
  bool _togglingHold = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final salon = widget.salon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Logo + Name ────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                backgroundImage: salon.photoUrl != null
                    ? NetworkImage(salon.photoUrl!)
                    : null,
                child: salon.photoUrl == null
                    ? Icon(
                        Icons.store,
                        size: BCSpacing.iconLg,
                        color: colors.primary,
                      )
                    : null,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                salon.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xs),
              if (salon.city != null)
                Text(
                  salon.city!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              const SizedBox(height: BCSpacing.sm),
              Wrap(
                spacing: BCSpacing.sm,
                runSpacing: BCSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  _VerifiedBadge(verified: salon.verified),
                  _StripeStatusBadge(status: salon.stripeStatus),
                  _BankingStatusBadge(
                    bankingComplete: salon.bankingComplete,
                    idStatus: salon.idVerificationStatus,
                  ),
                  if (!salon.isActive) _SuspensionBadge(suspended: true),
                  if (salon.onHold) _SuspensionBadge(suspended: false),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Stats ──────────────────────────────────────────────────────
        _SectionTitle(title: 'Estadisticas'),
        const SizedBox(height: BCSpacing.sm),
        Row(
          children: [
            _StatCard(
              label: 'Rating',
              value: salon.rating > 0
                  ? salon.rating.toStringAsFixed(1)
                  : '-',
              icon: Icons.star,
            ),
            const SizedBox(width: BCSpacing.sm),
            _StatCard(
              label: 'Reviews',
              value: '${salon.totalReviews}',
              icon: Icons.rate_review,
            ),
            const SizedBox(width: BCSpacing.sm),
            _StatCard(
              label: 'Tier',
              value: '${salon.tier}',
              icon: Icons.workspace_premium,
            ),
          ],
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.star,
          label: 'Rating',
          value: salon.rating > 0
              ? '${salon.rating.toStringAsFixed(1)} / 5.0'
              : 'Sin calificaciones',
          trailing: salon.rating > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < salon.rating.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    );
                  }),
                )
              : null,
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Contact ────────────────────────────────────────────────────
        _SectionTitle(title: 'Contacto'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: salon.phone ?? 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Registrado',
          value: dateFormat.format(salon.createdAt),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── License ──────────────────────────────────────────────────
        _SectionTitle(title: 'Licencia Municipal'),
        const SizedBox(height: BCSpacing.sm),
        _buildLicenseSection(context, salon),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Banking ───────────────────────────────────────────────────
        _SectionTitle(title: 'Informacion Bancaria'),
        const SizedBox(height: BCSpacing.sm),
        _buildBankingSection(context, salon),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ────────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _togglingVerified
                ? null
                : () async {
                    setState(() => _togglingVerified = true);
                    try {
                      final newValue = !salon.verified;
                      await BCSupabase.client
                          .from(BCTables.businesses)
                          .update({'is_verified': newValue})
                          .eq('id', salon.id);
                      try {
                        await BCSupabase.client.rpc(
                          'log_admin_action',
                          params: {
                            'p_action': 'salon_verify_toggle',
                            'p_target_type': 'business',
                            'p_target_id': salon.id,
                            'p_details': {
                              'prev_value': salon.verified,
                              'new_value': newValue,
                            },
                          },
                        );
                      } catch (logErr) {
                        debugPrint('admin audit log insert failed (verify toggle): $logErr');
                      }
                      ref.invalidate(registeredSalonsProvider);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _togglingVerified = false);
                      }
                    }
                  },
            icon: _togglingVerified
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    salon.verified
                        ? Icons.remove_circle_outline
                        : Icons.verified_outlined,
                    size: 18,
                  ),
            label: Text(
              salon.verified ? 'Quitar verificacion' : 'Verificar salon',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  salon.verified ? colors.error : Colors.green,
            ),
          ),
        ),

        const SizedBox(height: BCSpacing.sm),

        // ── On Hold toggle ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _togglingHold
                ? null
                : () => _toggleHold(context, salon),
            icon: _togglingHold
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    salon.onHold
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 18,
                  ),
            label: Text(
              salon.onHold
                  ? 'Quitar pausa (visible en busqueda)'
                  : 'Pausar salon (ocultar de busqueda)',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  salon.onHold ? Colors.blue : Colors.orange,
            ),
          ),
        ),

        const SizedBox(height: BCSpacing.sm),

        // ── Suspend / Reactivate ────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _suspendingOrReactivating
                ? null
                : () => salon.isActive
                    ? _suspendSalon(context, salon)
                    : _reactivateSalon(context, salon),
            icon: _suspendingOrReactivating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    salon.isActive ? Icons.block : Icons.restore,
                    size: 18,
                  ),
            label: Text(
              salon.isActive ? 'Suspender salon' : 'Reactivar salon',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  salon.isActive ? colors.error : Colors.green,
              side: BorderSide(
                color: salon.isActive
                    ? colors.error.withValues(alpha: 0.5)
                    : Colors.green.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── On Hold toggle ─────────────────────────────────────────────────────────

  Future<void> _toggleHold(
    BuildContext context,
    RegisteredSalon salon,
  ) async {
    final action = salon.onHold ? 'unhold' : 'hold';
    final confirmLabel = salon.onHold
        ? 'Quitar pausa a ${salon.name}?'
        : 'Pausar ${salon.name}? Desaparecera de la busqueda pero no se notificara a clientes.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(salon.onHold ? 'Quitar pausa' : 'Pausar salon'),
        content: Text(confirmLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(salon.onHold ? 'Quitar pausa' : 'Pausar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _togglingHold = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'suspend-salon',
        body: {'business_id': salon.id, 'action': action},
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data['error'] != null) throw Exception(data['error']);

      ref.invalidate(registeredSalonsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              salon.onHold
                  ? '${salon.name} visible de nuevo'
                  : '${salon.name} pausado',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingHold = false);
    }
  }

  // ── Suspend — triple confirmation ──────────────────────────────────────────

  Future<void> _suspendSalon(
    BuildContext context,
    RegisteredSalon salon,
  ) async {
    // Step 1: Fetch affected booking count
    int affectedCount = 0;
    try {
      final result = await BCSupabase.client
          .from(BCTables.appointments)
          .select('id')
          .eq('business_id', salon.id)
          .inFilter('status', ['pending', 'confirmed'])
          .gte('starts_at', DateTime.now().toUtc().toIso8601String());
      affectedCount = (result as List).length;
    } catch (_) {
      // If count query fails, we still show 0 and let admin decide
    }

    if (!mounted) return;

    // Step 1 dialog: Show impact
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspender salon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salon: ${salon.name}'),
            const SizedBox(height: BCSpacing.sm),
            Text(
              affectedCount > 0
                  ? 'Hay $affectedCount cita(s) pendiente(s)/confirmada(s) a futuro. '
                    'Cada cliente recibira una notificacion.'
                  : 'No hay citas futuras afectadas.',
              style: affectedCount > 0
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
            const SizedBox(height: BCSpacing.sm),
            const Text(
              'Las citas NO se cancelaran. El cliente decide.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Entiendo, continuar'),
          ),
        ],
      ),
    );

    if (step1 != true || !mounted) return;

    // Step 2 dialog: Acknowledge impact
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar suspension'),
        content: Text(
          affectedCount > 0
              ? 'Se enviaran $affectedCount notificaciones a clientes. '
                'Esta accion es visible para los usuarios. Continuar?'
              : 'El salon dejara de aparecer y no podra recibir citas. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Si, suspender'),
          ),
        ],
      ),
    );

    if (step2 != true || !mounted) return;

    // Step 3 dialog: Type salon name to confirm
    final nameController = TextEditingController();
    final step3 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final matches = nameController.text.trim().toLowerCase() ==
                salon.name.trim().toLowerCase();
            return AlertDialog(
              title: const Text('Ultima confirmacion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escribe el nombre del salon para confirmar:',
                  ),
                  const SizedBox(height: BCSpacing.sm),
                  Text(
                    '"${salon.name}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: BCSpacing.sm),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Nombre del salon',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: matches
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  child: const Text('SUSPENDER'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (step3 != true || !mounted) return;

    // Execute suspension
    setState(() => _suspendingOrReactivating = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'suspend-salon',
        body: {'business_id': salon.id, 'action': 'suspend'},
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data['error'] != null) throw Exception(data['error']);

      final count = data['affected_bookings'] ?? 0;
      ref.invalidate(registeredSalonsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${salon.name} suspendido. $count cliente(s) notificado(s).',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al suspender: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _suspendingOrReactivating = false);
    }
  }

  // ── Reactivate ─────────────────────────────────────────────────────────────

  Future<void> _reactivateSalon(
    BuildContext context,
    RegisteredSalon salon,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivar salon'),
        content: Text(
          'Reactivar ${salon.name}? Volvera a aparecer en busquedas y podra recibir citas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _suspendingOrReactivating = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'suspend-salon',
        body: {'business_id': salon.id, 'action': 'reactivate'},
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data['error'] != null) throw Exception(data['error']);

      ref.invalidate(registeredSalonsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${salon.name} reactivado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _suspendingOrReactivating = false);
    }
  }

  Widget _buildLicenseSection(BuildContext context, RegisteredSalon salon) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (salon.municipalLicenseStatus == 'none' ||
        salon.municipalLicenseUrl == null) {
      return Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: BCSpacing.sm),
          Text(
            'Sin licencia subida',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            salon.municipalLicenseUrl!,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: colors.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        _LicenseStatusBadge(status: salon.municipalLicenseStatus),
        // Approve/reject buttons if pending
        if (salon.municipalLicenseStatus == 'pending') ...[
          const SizedBox(height: BCSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _approvingLicense
                      ? null
                      : () async {
                          setState(() => _approvingLicense = true);
                          try {
                            final userId = BCSupabase.currentUserId;
                            await BCSupabase.client
                                .from(BCTables.businesses)
                                .update({
                              'municipal_license_status': 'approved',
                              'municipal_license_reviewed_at':
                                  DateTime.now().toUtc().toIso8601String(),
                              'municipal_license_reviewed_by': userId,
                            }).eq('id', salon.id);
                            ref.invalidate(registeredSalonsProvider);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _approvingLicense = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aprobar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: BCSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rejectingLicense
                      ? null
                      : () async {
                          setState(() => _rejectingLicense = true);
                          try {
                            final userId = BCSupabase.currentUserId;
                            await BCSupabase.client
                                .from(BCTables.businesses)
                                .update({
                              'municipal_license_status': 'rejected',
                              'municipal_license_reviewed_at':
                                  DateTime.now().toUtc().toIso8601String(),
                              'municipal_license_reviewed_by': userId,
                            }).eq('id', salon.id);
                            ref.invalidate(registeredSalonsProvider);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _rejectingLicense = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool _overridingBanking = false;

  Widget _buildBankingSection(BuildContext context, RegisteredSalon salon) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (statusLabel, statusColor) = salon.bankingComplete
        ? ('Completa', Colors.green)
        : switch (salon.idVerificationStatus) {
            'pending' => ('Verificacion en proceso', Colors.orange),
            'rejected' => ('ID rechazada', Colors.red),
            'verified' => ('ID verificada, CLABE pendiente', Colors.orange),
            _ => ('No iniciada', kWebTextHint),
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: BCSpacing.sm),

        // Banking details (if any data exists)
        if (salon.clabe != null) ...[
          _InfoRow(
            icon: Icons.account_balance_outlined,
            label: 'CLABE',
            value: salon.clabe!,
          ),
        ],
        if (salon.bankName != null)
          _InfoRow(
            icon: Icons.business_outlined,
            label: 'Banco',
            value: salon.bankName!,
          ),
        if (salon.beneficiaryName != null)
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Beneficiario',
            value: salon.beneficiaryName!,
          ),

        if (salon.clabe == null &&
            salon.idVerificationStatus == 'none') ...[
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16,
                  color: colors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: BCSpacing.sm),
              Text(
                'Sin informacion bancaria',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],

        // Manual override button
        if (!salon.bankingComplete) ...[
          const SizedBox(height: BCSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _overridingBanking
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Aprobar banca manualmente'),
                          content: const Text(
                            'Esto marcara la verificacion bancaria como completa '
                            'y permitira que el salon reciba reservas. '
                            'Solo usa esto si verificaste la informacion por otro medio.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Aprobar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                      setState(() => _overridingBanking = true);
                      try {
                        await BCSupabase.client
                            .from(BCTables.businesses)
                            .update({
                          'banking_complete': true,
                          'id_verification_status': 'verified',
                        }).eq('id', salon.id);
                        ref.invalidate(registeredSalonsProvider);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _overridingBanking = false);
                        }
                      }
                    },
              icon: _overridingBanking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Aprobar banca manualmente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: BCSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _overridingBanking
                  ? null
                  : () async {
                      setState(() => _overridingBanking = true);
                      try {
                        await BCSupabase.client
                            .from(BCTables.businesses)
                            .update({
                          'banking_complete': false,
                          'id_verification_status': 'rejected',
                        }).eq('id', salon.id);
                        ref.invalidate(registeredSalonsProvider);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _overridingBanking = false);
                        }
                      }
                    },
              icon: _overridingBanking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.block_outlined, size: 18),
              label: const Text('Revocar verificacion bancaria'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Detail panel content for a discovered salon.
class DiscoveredSalonDetailContent extends ConsumerStatefulWidget {
  const DiscoveredSalonDetailContent({required this.salon, super.key});

  final DiscoveredSalon salon;

  @override
  ConsumerState<DiscoveredSalonDetailContent> createState() =>
      _DiscoveredSalonDetailContentState();
}

class _DiscoveredSalonDetailContentState
    extends ConsumerState<DiscoveredSalonDetailContent> {
  bool _sendingInvite = false;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 30) return 'hace ${diff.inDays} dias';
    if (diff.inDays < 365) return 'hace ${diff.inDays ~/ 30} meses';
    return 'hace ${diff.inDays ~/ 365} anos';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _openUrl(String url) {
    var uri = url;
    if (!uri.startsWith('http://') && !uri.startsWith('https://')) {
      uri = 'https://$uri';
    }
    launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 300,
                  height: 300,
                  color: Colors.black54,
                  child: const Center(
                    child: Icon(Icons.broken_image,
                        size: 48, color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final salon = widget.salon;
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: colors.primary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name + Source + Photo ──────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.secondary.withValues(alpha: 0.1),
                backgroundImage: salon.photoUrl != null
                    ? NetworkImage(salon.photoUrl!)
                    : null,
                child: salon.photoUrl == null
                    ? Icon(
                        Icons.explore,
                        size: BCSpacing.iconLg,
                        color: colors.secondary,
                      )
                    : null,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                salon.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SourceBadge(source: salon.source),
                  if (salon.rating != null && salon.rating! > 0) ...[
                    const SizedBox(width: BCSpacing.xs),
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${salon.rating!.toStringAsFixed(1)} (${salon.reviewCount ?? 0})',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── Categories ──────────────────────────────────────────────
        if (salon.categories.isNotEmpty) ...[
          const SizedBox(height: BCSpacing.sm),
          Center(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: salon.categories
                  .map((cat) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(BCSpacing.radiusFull),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],

        // ── Enrichment Status Bar ─────────────────────────────────────
        const SizedBox(height: BCSpacing.md),
        _HoverLift(child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BCSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sync, size: 14,
                      color: colors.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text('Enrichment',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      )),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _EnrichmentChip(
                    label: 'WA',
                    done: salon.waCheckedAt != null,
                    verified: salon.waStatus == 'valid',
                  ),
                  _EnrichmentChip(
                    label: 'IG',
                    done: salon.isIgEnriched,
                  ),
                  _EnrichmentChip(
                    label: 'Web',
                    done: salon.website != null &&
                        salon.website!.isNotEmpty,
                  ),
                  _EnrichmentChip(
                    label: 'Booking',
                    done: salon.bookingSystem != null &&
                        salon.bookingSystem!.isNotEmpty,
                  ),
                  _EnrichmentChip(
                    label: 'Email',
                    done: salon.email != null && salon.email!.isNotEmpty,
                  ),
                  _EnrichmentChip(
                    label: 'FB',
                    done: salon.facebookUrl != null &&
                        salon.facebookUrl!.isNotEmpty,
                  ),
                ],
              ),
              if (salon.waCheckedAt != null || salon.isIgEnriched) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (salon.waCheckedAt != null)
                      'WA: ${_relativeTime(salon.waCheckedAt!)}',
                    if (salon.isIgEnriched)
                      'IG: ${_relativeTime(salon.igEnrichedAt!)}',
                    if (salon.bookingEnrichedAt != null)
                      'Booking: ${_relativeTime(salon.bookingEnrichedAt!)}',
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        )),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Contact Info (complete) ──────────────────────────────────
        _SectionTitle(title: 'Contacto'),
        const SizedBox(height: BCSpacing.sm),

        // Phone — clickable tel: link with WA badge
        if (salon.phone != null) ...[
          _HoverContactLink(
            icon: Icons.phone_outlined,
            iconColor: colors.onSurface.withValues(alpha: 0.5),
            label: salon.phone!,
            onTap: () => launchUrl(Uri.parse('tel:${salon.phone}')),
            trailing: _WaStatusBadge(status: salon.waStatus),
          ),
          const SizedBox(height: BCSpacing.xs),
          // WhatsApp direct link
          _HoverContactLink(
            icon: Icons.chat,
            iconColor: Colors.green,
            label: 'WhatsApp',
            onTap: () {
              final cleanPhone =
                  salon.phone!.replaceAll(RegExp(r'[^\d+]'), '');
              launchUrl(
                Uri.parse('https://wa.me/$cleanPhone'),
                mode: LaunchMode.externalApplication,
              );
            },
            trailing: salon.whatsappVerified == true
                ? const Icon(Icons.verified, size: 12, color: Colors.green)
                : salon.whatsappVerified == false
                    ? const Icon(Icons.cancel, size: 12, color: Colors.red)
                    : null,
          ),
          const SizedBox(height: BCSpacing.sm),
        ] else ...[
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Telefono',
            value: 'No disponible',
          ),
          const SizedBox(height: BCSpacing.sm),
        ],

        // Email
        if (salon.email != null && salon.email!.isNotEmpty) ...[
          _HoverContactLink(
            icon: Icons.email_outlined,
            iconColor: colors.onSurface.withValues(alpha: 0.5),
            label: salon.email!,
            onTap: () => launchUrl(Uri.parse('mailto:${salon.email}')),
          ),
          const SizedBox(height: BCSpacing.sm),
        ],

        // Social links row — clickable
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (salon.instagramUrl != null)
              InkWell(
                onTap: () => _openUrl(salon.instagramUrl!),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt, size: 16,
                          color: Colors.pink),
                      const SizedBox(width: 4),
                      Text(
                        '@${Uri.parse(salon.instagramUrl!.endsWith('/') ? salon.instagramUrl!.substring(0, salon.instagramUrl!.length - 1) : salon.instagramUrl!).pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => salon.instagramUrl!)}',
                        style: linkStyle,
                      ),
                    ],
                  ),
                ),
              ),
            if (salon.facebookUrl != null &&
                salon.facebookUrl!.isNotEmpty)
              InkWell(
                onTap: () => _openUrl(salon.facebookUrl!),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.facebook, size: 16,
                          color: Colors.indigo),
                      const SizedBox(width: 4),
                      Text('Facebook', style: linkStyle),
                    ],
                  ),
                ),
              ),
            if (salon.website != null && salon.website!.isNotEmpty)
              InkWell(
                onTap: () => _openUrl(salon.website!),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language, size: 16,
                          color: colors.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        Uri.tryParse(salon.website!)?.host ??
                            salon.website!,
                        style: linkStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // ── Location ─────────────────────────────────────────────────
        const SizedBox(height: BCSpacing.md),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Ciudad',
          value: [salon.city, salon.state].where((s) => s != null).join(', '),
        ),
        const SizedBox(height: BCSpacing.sm),
        if (salon.address != null) ...[
          _InfoRow(
            icon: Icons.map_outlined,
            label: 'Direccion',
            value: salon.address!,
          ),
          const SizedBox(height: BCSpacing.sm),
        ],
        if (salon.latitude != null && salon.longitude != null) ...[
          _InfoRow(
            icon: Icons.gps_fixed,
            label: 'Coordenadas',
            value:
                '${salon.latitude!.toStringAsFixed(4)}, ${salon.longitude!.toStringAsFixed(4)}',
          ),
          const SizedBox(height: BCSpacing.sm),
        ],
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Descubierto',
          value: dateFormat.format(salon.createdAt),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.message_outlined,
          label: 'Ultimo contacto',
          value: salon.lastContactDate != null
              ? dateFormat.format(salon.lastContactDate!)
              : 'Nunca',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.trending_up,
          label: 'Senales de interes',
          value: '${salon.interestSignals}',
        ),

        // ── Bio (Google scraped) ─────────────────────────────────────
        if (salon.bio != null && salon.bio!.isNotEmpty) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle(title: 'Descripcion (Google)'),
          const SizedBox(height: BCSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BCSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            child: Text(
              salon.bio!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],

        // ── Instagram Section ────────────────────────────────────────
        if (salon.isIgEnriched || salon.instagramUrl != null) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle(title: 'Instagram'),
          const SizedBox(height: BCSpacing.sm),

          // Handle + followers
          Row(
            children: [
              if (salon.instagramUrl != null)
                InkWell(
                  onTap: () => _openUrl(salon.instagramUrl!),
                  child: Text(
                    '@${Uri.tryParse(salon.instagramUrl!.endsWith('/') ? salon.instagramUrl!.substring(0, salon.instagramUrl!.length - 1) : salon.instagramUrl!)?.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '?') ?? '?'}',
                    style: linkStyle?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              if (salon.igFollowers != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${_formatNumber(salon.igFollowers!)} seguidores',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),

          // IG Bio
          if (salon.igBio != null && salon.igBio!.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.xs),
            Text(
              salon.igBio!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Portfolio images — horizontal scroll
          if (salon.portfolioImages.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.sm),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: salon.portfolioImages.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: BCSpacing.xs),
                itemBuilder: (context, index) {
                  final imgUrl = salon.portfolioImages[index];
                  return _PortfolioThumb(
                    imageUrl: imgUrl,
                    onTap: () => _showImageDialog(context, imgUrl),
                    colors: colors,
                  );
                },
              ),
            ),
          ],

          // Last post caption
          if (salon.igPostCaptions != null &&
              salon.igPostCaptions!.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, size: 14,
                    color: colors.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    salon.igPostCaptions!.length > 100
                        ? '${salon.igPostCaptions!.substring(0, 100)}...'
                        : salon.igPostCaptions!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Enriched timestamp
          if (salon.igEnrichedAt != null) ...[
            const SizedBox(height: BCSpacing.xs),
            Text(
              'Enriquecido: ${_relativeTime(salon.igEnrichedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ],

        // ── Detected Services ────────────────────────────────────────
        if (salon.servicesDetected != null) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle(title: 'Servicios Detectados'),
          const SizedBox(height: BCSpacing.sm),
          _ServicesDetectedSection(data: salon.servicesDetected),
        ],

        // ── Working Hours ────────────────────────────────────────────
        if (salon.workingHours != null &&
            salon.workingHours!.isNotEmpty) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle(title: 'Horario'),
          const SizedBox(height: BCSpacing.sm),
          _WorkingHoursSection(data: salon.workingHours!),
        ],

        // ── Business Intelligence Estimates ────────────────────────
        if (salon.estMonthlyClients != null) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle(title: 'Inteligencia de Negocio (estimado)'),
          const SizedBox(height: BCSpacing.sm),
          _HoverLift(child: _ShimmerBorderContainer(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _BizIntelCard(
                      icon: Icons.people_outline,
                      label: 'Clientes/mes',
                      value: '~${salon.estMonthlyClients}',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _BizIntelCard(
                      icon: Icons.today_outlined,
                      label: 'Clientes/dia',
                      value: '~${salon.estDailyClients?.toStringAsFixed(0)}',
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _BizIntelCard(
                      icon: Icons.attach_money,
                      label: 'Precio promedio',
                      value: '\$${salon.estAvgServicePrice?.toStringAsFixed(0)} MXN',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _BizIntelCard(
                      icon: Icons.trending_up,
                      label: 'Rev. mensual',
                      value: '\$${_fmtRevenue(salon.estMonthlyRevenue)} MXN',
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rev. anual estimado: \$${_fmtRevenue(salon.estAnnualRevenue)} MXN',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFec4899),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Basado en ${salon.reviewCount ?? 0} resenas Google · Precio estimado por categoria',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          )),
        ],

        // ── Booking System ───────────────────────────────────────────
        if (salon.bookingSystem != null ||
            salon.bookingUrl != null ||
            salon.calendarUrl != null) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle(title: 'Sistema de Reservas'),
          const SizedBox(height: BCSpacing.sm),
          if (salon.bookingSystem != null)
            _InfoRow(
              icon: Icons.event_available,
              label: 'Sistema',
              value: salon.bookingSystem!,
            ),
          if (salon.bookingUrl != null) ...[
            const SizedBox(height: BCSpacing.sm),
            Row(
              children: [
                Icon(Icons.open_in_new, size: 16,
                    color: colors.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: BCSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => _openUrl(salon.bookingUrl!),
                    child: Text(
                      salon.bookingUrl!,
                      style: linkStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (salon.calendarUrl != null) ...[
            const SizedBox(height: BCSpacing.sm),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 16,
                    color: colors.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: BCSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => _openUrl(salon.calendarUrl!),
                    child: Text(
                      'Calendario',
                      style: linkStyle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],

        // ── Enrichment Stats Row ─────────────────────────────────────
        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),
        _SectionTitle(title: 'Metricas'),
        const SizedBox(height: BCSpacing.sm),
        Row(
          children: [
            _StatCard(
              label: 'WA',
              value: salon.waStatus == 'valid'
                  ? 'OK'
                  : salon.waStatus == 'invalid'
                      ? 'No'
                      : '?',
              icon: Icons.chat,
            ),
            const SizedBox(width: BCSpacing.sm),
            _StatCard(
              label: 'IG',
              value: salon.isIgEnriched
                  ? _formatNumber(salon.igFollowers ?? 0)
                  : salon.instagramUrl != null
                      ? 'Pending'
                      : 'N/A',
              icon: Icons.camera_alt,
            ),
            const SizedBox(width: BCSpacing.sm),
            _StatCard(
              label: 'Rating',
              value: salon.rating != null
                  ? salon.rating!.toStringAsFixed(1)
                  : '-',
              icon: Icons.star,
            ),
          ],
        ),

        // ── Contact History ────────────────────────────────────────────
        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),
        _SectionTitle(title: 'Historial de contacto'),
        const SizedBox(height: BCSpacing.sm),
        Consumer(builder: (context, ref, _) {
          final historyAsync =
              ref.watch(salonOutreachHistoryProvider(salon.id));
          return historyAsync.when(
            data: (entries) => entries.isEmpty
                ? Text('Sin contacto previo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ))
                : Column(
                    children: entries
                        .take(10)
                        .map((e) => _ContactHistoryTile(entry: e))
                        .toList(),
                  ),
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: theme.textTheme.bodySmall),
          );
        }),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ────────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),
        _HoverActionButton(
          onPressed: () => _openContactPanel(context, ref, salon),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openContactPanel(context, ref, salon),
              icon: const Icon(Icons.contact_phone, size: 18),
              label: const Text('Contactar'),
            ),
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        _HoverActionButton(
          onPressed: null, // Actual handler on inner OutlinedButton
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendingInvite
                ? null
                : () async {
                    setState(() => _sendingInvite = true);
                    try {
                      await BCSupabase.client.functions.invoke(
                        'outreach-discovered-salon',
                        body: {
                          'action': 'invite',
                          'discovered_salon_id': salon.id,
                        },
                      );
                      ref.invalidate(discoveredSalonsProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Invitacion enviada a ${salon.name}',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _sendingInvite = false);
                      }
                    }
                  },
            icon: _sendingInvite
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 18),
            label: const Text('Enviar invitacion WA'),
            ),
          ),
        ),
      ],
    );
  }

  void _openContactPanel(
    BuildContext context,
    WidgetRef ref,
    DiscoveredSalon salon,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(BCSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: ContactPanel(
            salon: salon,
            onClose: () => Navigator.of(ctx).pop(),
            onSent: () {
              ref.invalidate(salonOutreachHistoryProvider(salon.id));
              ref.invalidate(discoveredSalonsProvider);
            },
          ),
        ),
      ),
    );
  }
}

// ── Contact History Tile ──────────────────────────────────────────────────────

class _ContactHistoryTile extends StatelessWidget {
  const _ContactHistoryTile({required this.entry});
  final OutreachLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM HH:mm', 'es');

    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.channelIcon, size: 16, color: entry.outcomeColor),
          const SizedBox(width: BCSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.channelLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateFormat.format(entry.sentAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (entry.outcome != null) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: entry.outcomeColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(BCSpacing.radiusFull),
                    ),
                    child: Text(
                      entry.outcome!,
                      style: TextStyle(
                        color: entry.outcomeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (entry.messageText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.messageText!.length > 80
                        ? '${entry.messageText!.substring(0, 80)}...'
                        : entry.messageText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.rpDisplayName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Por: ${entry.rpDisplayName}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(BCSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(height: BCSpacing.xs),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? Colors.green : Colors.orange;
    final label = verified ? 'Verificado' : 'No verificado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified : Icons.pending,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeStatusBadge extends StatelessWidget {
  const _StripeStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'complete' => ('Stripe OK', Colors.green),
      'pending' || 'pending_verification' => ('Stripe pendiente', Colors.orange),
      'not_started' => ('Sin Stripe', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BankingStatusBadge extends StatelessWidget {
  const _BankingStatusBadge({
    required this.bankingComplete,
    required this.idStatus,
  });
  final bool bankingComplete;
  final String idStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color) = bankingComplete
        ? ('Banca OK', Colors.green)
        : switch (idStatus) {
            'pending' => ('ID pendiente', Colors.orange),
            'rejected' => ('ID rechazada', Colors.red),
            _ => ('Sin banca', Colors.grey),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LicenseStatusBadge extends StatelessWidget {
  const _LicenseStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Pendiente de revision', Colors.orange),
      'approved' => ('Verificado', Colors.green),
      'rejected' => ('Rechazada', Colors.red),
      _ => ('Sin licencia', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 'approved'
                ? Icons.verified
                : status == 'rejected'
                    ? Icons.cancel
                    : Icons.schedule,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({this.source});
  final String? source;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'google_maps' => ('Google Maps', Colors.blue),
      'facebook' => ('Facebook', Colors.indigo),
      'bing' => ('Bing', Colors.teal),
      _ => (source ?? 'Desconocido', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WaStatusBadge extends StatelessWidget {
  const _WaStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'valid' => (Icons.check_circle, Colors.green),
      'invalid' => (Icons.cancel, Colors.red),
      _ => (Icons.help_outline, Colors.grey),
    };

    return Icon(icon, size: 16, color: color);
  }
}

class _EnrichmentChip extends StatelessWidget {
  const _EnrichmentChip({
    required this.label,
    required this.done,
    this.verified,
  });
  final String label;
  final bool done;
  final bool? verified;

  @override
  Widget build(BuildContext context) {
    // For WA: verified=true means green check, verified=false means red x,
    // done but verified==null means orange (checked but ambiguous)
    final Color color;
    final IconData icon;
    if (done) {
      if (verified == false) {
        color = Colors.red;
        icon = Icons.cancel;
      } else {
        color = Colors.green;
        icon = Icons.check_circle;
      }
    } else {
      color = Colors.grey;
      icon = Icons.radio_button_unchecked;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ServicesDetectedSection extends StatelessWidget {
  const _ServicesDetectedSection({required this.data});
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    List<String> services = [];
    if (data is List) {
      services = (data as List).map((e) => e.toString()).toList();
    } else if (data is Map) {
      // Map structure — flatten keys and values
      (data as Map).forEach((key, value) {
        if (value is List) {
          for (final v in value) {
            services.add(v.toString());
          }
        } else {
          services.add('$key: $value');
        }
      });
    } else if (data is String) {
      // Try parsing as JSON
      try {
        final parsed = jsonDecode(data as String);
        if (parsed is List) {
          services = parsed.map((e) => e.toString()).toList();
        }
      } catch (_) {
        services = [data as String];
      }
    }

    if (services.isEmpty) {
      return Text(
        'Sin servicios detectados',
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: colors.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: services.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
            border: Border.all(
              color: colors.tertiary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            s,
            style: TextStyle(
              color: colors.tertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BizIntelCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BizIntelCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            )),
          ]),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}

String _fmtRevenue(double? amount) {
  if (amount == null) return '0';
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
  return amount.toStringAsFixed(0);
}

class _WorkingHoursSection extends StatelessWidget {
  const _WorkingHoursSection({required this.data});
  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Try to parse as JSON (common format from Google)
    dynamic parsed;
    try {
      parsed = jsonDecode(data);
    } catch (_) {
      parsed = null;
    }

    if (parsed is Map) {
      // Map of day -> hours
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parsed.entries.map<Widget>((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (parsed is List) {
      // List of strings like "Monday: 9 AM - 6 PM"
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parsed.map<Widget>((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );
        }).toList(),
      );
    }

    // Plain text — split by common delimiters
    final lines = data.contains('\n')
        ? data.split('\n')
        : data.contains(';')
            ? data.split(';')
            : data.contains(',')
                ? data.split(',')
                : [data];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .where((l) => l.trim().isNotEmpty)
          .map<Widget>((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            line.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SuspensionBadge extends StatelessWidget {
  const _SuspensionBadge({required this.suspended});

  /// true = suspended (is_active=false), false = on hold
  final bool suspended;

  @override
  Widget build(BuildContext context) {
    final label = suspended ? 'Suspendido' : 'En pausa';
    final color = suspended ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            suspended ? Icons.block : Icons.pause_circle_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hover lift widget ─────────────────────────────────────────────────────────

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child});
  final Widget child;
  static const double _liftPx = 2;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovering ? -_HoverLift._liftPx : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Biz intel shimmer border ──────────────────────────────────────────────────

class _ShimmerBorderContainer extends StatefulWidget {
  const _ShimmerBorderContainer({required this.child});
  final Widget child;

  @override
  State<_ShimmerBorderContainer> createState() => _ShimmerBorderContainerState();
}

class _ShimmerBorderContainerState extends State<_ShimmerBorderContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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
        final opacity = 0.1 + (_controller.value * 0.15);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFec4899).withValues(alpha: 0.05),
                const Color(0xFF9333ea).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFec4899).withValues(alpha: opacity),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── Portfolio image hover zoom ────────────────────────────────────────────────

class _PortfolioThumb extends StatefulWidget {
  const _PortfolioThumb({
    required this.imageUrl,
    required this.onTap,
    required this.colors,
  });
  final String imageUrl;
  final VoidCallback onTap;
  final ColorScheme colors;

  @override
  State<_PortfolioThumb> createState() => _PortfolioThumbState();
}

class _PortfolioThumbState extends State<_PortfolioThumb> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            child: AnimatedScale(
              scale: _hovering ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Image.network(
                widget.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: widget.colors.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contact link with hover ───────────────────────────────────────────────────

class _HoverContactLink extends StatefulWidget {
  const _HoverContactLink({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_HoverContactLink> createState() => _HoverContactLinkState();
}

class _HoverContactLinkState extends State<_HoverContactLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const brandPink = Color(0xFFec4899);
    final textColor = _hovering ? brandPink : colors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(widget.icon, size: 16, color: _hovering ? brandPink : widget.iconColor),
            ),
            const SizedBox(width: BCSpacing.sm),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: textColor,
                  decoration: _hovering ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: textColor,
                ),
                child: Text(widget.label),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

// ── Action button with hover glow ─────────────────────────────────────────────

class _HoverActionButton extends StatefulWidget {
  const _HoverActionButton({
    required this.child,
    required this.onPressed,
  });
  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(_hovering ? 1.02 : 1.0, _hovering ? 1.02 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: const Color(0xFFec4899).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: const Color(0xFF9333ea).withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
