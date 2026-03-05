import 'dart:convert';

import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_salons_provider.dart';

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
                      await BCSupabase.client
                          .from(BCTables.businesses)
                          .update({'is_verified': !salon.verified})
                          .eq('id', salon.id);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final salon = widget.salon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name + Source ──────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.secondary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.explore,
                  size: BCSpacing.iconLg,
                  color: colors.secondary,
                ),
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
              _SourceBadge(source: salon.source),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Info ────────────────────────────────────────────────────────
        _SectionTitle(title: 'Informacion'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: salon.phone ?? 'No disponible',
          trailing: salon.phone != null
              ? _WaStatusBadge(status: salon.waStatus)
              : null,
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Ciudad',
          value: salon.city ?? 'Desconocida',
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

        if (salon.latitude != null && salon.longitude != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.gps_fixed,
            label: 'Coordenadas',
            value:
                '${salon.latitude!.toStringAsFixed(4)}, ${salon.longitude!.toStringAsFixed(4)}',
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ────────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),
        SizedBox(
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
      ],
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
