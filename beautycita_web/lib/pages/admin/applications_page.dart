import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_applications_provider.dart';
import '../../widgets/bc_data_table.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/master_detail_layout.dart';
import '../../widgets/pagination_bar.dart';

/// Admin page for monitoring pending business applications.
/// Applications are auto-approved when the owner verifies both phone + email.
class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  ApplicationBusiness? _selected;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filter = ref.watch(applicationsFilterProvider);
    final appsAsync = ref.watch(applicationsProvider);
    final dateFormat = DateFormat('d MMM yy', 'es');

    if (appsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: colors.error.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('Error cargando solicitudes',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                '${appsAsync.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(applicationsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = appsAsync.valueOrNull?.applications ?? [];
    final totalCount = appsAsync.valueOrNull?.totalCount ?? 0;
    final isLoading = appsAsync.isLoading;
    final totalPages = (totalCount / filter.pageSize).ceil();

    return MasterDetailLayout<ApplicationBusiness>(
      items: items,
      isLoading: isLoading,
      selectedItem: _selected,
      onSelect: (app) => setState(() => _selected = app),
      detailTitle: _selected?.name ?? 'Solicitud',
      detailBuilder: (app) => _ApplicationDetailContent(
        application: app,
        onDismiss: () => setState(() => _selected = null),
      ),
      filterBar: FilterBar(
        searchField: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar solicitud...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            suffixIcon: filter.searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref
                          .read(applicationsFilterProvider.notifier)
                          .state = filter.copyWith(
                        searchText: '',
                        page: 0,
                      );
                    },
                  )
                : null,
          ),
          onChanged: (value) => setApplicationsSearch(ref, value),
        ),
        filters: const [],
        onClearAll: null,
      ),
      table: BCDataTable<ApplicationBusiness>(
        columns: [
          BCColumn<ApplicationBusiness>(
            id: 'name',
            label: 'Nombre',
            sortable: true,
            cellBuilder: (app) => Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  backgroundImage: app.photoUrl != null
                      ? NetworkImage(app.photoUrl!)
                      : null,
                  child: app.photoUrl == null
                      ? Icon(Icons.store, size: 14, color: colors.primary)
                      : null,
                ),
                const SizedBox(width: BCSpacing.sm),
                Flexible(
                  child: Text(
                    app.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          BCColumn<ApplicationBusiness>(
            id: 'city',
            label: 'Ciudad',
            sortable: true,
            cellBuilder: (app) => Text(
              app.city ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<ApplicationBusiness>(
            id: 'phone',
            label: 'Telefono',
            cellBuilder: (app) => Text(
              app.phone ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<ApplicationBusiness>(
            id: 'verification',
            label: 'Verificacion',
            width: 90,
            cellBuilder: (app) => _VerificationChip(
              emailOk: app.ownerEmailVerified,
              phoneOk: app.ownerPhoneVerified,
            ),
          ),
          BCColumn<ApplicationBusiness>(
            id: 'created_at',
            label: 'Fecha',
            sortable: true,
            width: 100,
            cellBuilder: (app) => Text(
              dateFormat.format(app.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
            ),
          ),
        ],
        items: items,
        selectedItems: const {},
        selectedItem: _selected,
        isLoading: isLoading,
        sortColumn: filter.sortColumn,
        sortAscending: filter.sortAscending,
        onRowTap: (app) => setState(() => _selected = app),
        onSelectionChanged: (_) {},
        onSort: (column) {
          final ascending =
              filter.sortColumn == column ? !filter.sortAscending : true;
          ref.read(applicationsFilterProvider.notifier).state =
              filter.copyWith(
            sortColumn: () => column,
            sortAscending: ascending,
          );
        },
        emptyIcon: Icons.assignment_outlined,
        emptyTitle: 'No hay solicitudes pendientes',
        emptySubtitle: filter.searchText.isNotEmpty
            ? 'Intenta con otros terminos'
            : 'Se auto-aprueban cuando verifican email y telefono',
      ),
      pagination: totalPages > 1
          ? PaginationBar(
              currentPage: filter.page,
              totalPages: totalPages,
              totalItems: totalCount,
              pageSize: filter.pageSize,
              onPageChanged: (page) {
                ref
                    .read(applicationsFilterProvider.notifier)
                    .state = filter.copyWith(page: page);
              },
              onPageSizeChanged: (size) {
                ref
                    .read(applicationsFilterProvider.notifier)
                    .state = filter.copyWith(pageSize: size, page: 0);
              },
            )
          : null,
    );
  }
}

// ── Detail panel ─────────────────────────────────────────────────────────────

class _ApplicationDetailContent extends ConsumerStatefulWidget {
  const _ApplicationDetailContent({
    required this.application,
    required this.onDismiss,
  });
  final ApplicationBusiness application;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_ApplicationDetailContent> createState() =>
      _ApplicationDetailContentState();
}

class _ApplicationDetailContentState
    extends ConsumerState<_ApplicationDetailContent> {
  bool _rejecting = false;
  bool _approvingLicense = false;
  bool _rejectingLicense = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final app = widget.application;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Avatar + Name ──────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                backgroundImage: app.photoUrl != null
                    ? NetworkImage(app.photoUrl!)
                    : null,
                child: app.photoUrl == null
                    ? Icon(
                        Icons.store,
                        size: BCSpacing.iconLg,
                        color: colors.primary,
                      )
                    : null,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                app.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xs),
              if (app.city != null)
                Text(
                  app.city!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              const SizedBox(height: BCSpacing.sm),
              _StatusBadge(label: 'Pendiente', color: Colors.orange),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Verification status ──────────────────────────────────────
        _SectionTitle(title: 'Requisitos para aprobacion'),
        const SizedBox(height: BCSpacing.xs),
        Text(
          'Se aprueba automaticamente al verificar ambos.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        _VerificationRow(
          icon: Icons.email_outlined,
          label: 'Email verificado',
          verified: app.ownerEmailVerified,
        ),
        const SizedBox(height: BCSpacing.xs),
        _VerificationRow(
          icon: Icons.phone_outlined,
          label: 'Telefono verificado',
          verified: app.ownerPhoneVerified,
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Info ────────────────────────────────────────────────────────
        _SectionTitle(title: 'Informacion'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono del negocio',
          value: app.phone ?? 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Fecha de registro',
          value: dateFormat.format(app.createdAt),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.checklist_outlined,
          label: 'Paso de onboarding',
          value: _onboardingLabel(app.onboardingStep),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.payment_outlined,
          label: 'Stripe',
          value: _stripeLabel(app.stripeOnboardingStatus),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── License ──────────────────────────────────────────────────
        _SectionTitle(title: 'Licencia Municipal'),
        const SizedBox(height: BCSpacing.sm),
        _buildLicenseSection(context, app),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ──────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _rejecting
                ? null
                : () => _showRejectDialog(context, app),
            icon: _rejecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Rechazar Solicitud'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseSection(
      BuildContext context, ApplicationBusiness app) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (app.municipalLicenseStatus == 'none' ||
        app.municipalLicenseUrl == null) {
      return Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: BCSpacing.sm),
          Text(
            'Opcional — sin licencia',
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
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            app.municipalLicenseUrl!,
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
        _LicenseStatusBadge(status: app.municipalLicenseStatus),
        if (app.municipalLicenseStatus == 'pending') ...[
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
                            await approveLicense(ref, app.id);
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
                            await rejectLicense(ref, app.id);
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

  Future<void> _showRejectDialog(
      BuildContext context, ApplicationBusiness app) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rechazar la solicitud de "${app.name}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Razon (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _rejecting = true);
      try {
        await rejectApplication(ref, app.id);
        if (mounted) widget.onDismiss();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _rejecting = false);
      }
    }
    reasonCtrl.dispose();
  }

  String _onboardingLabel(int step) {
    return switch (step) {
      0 => 'Paso 0 — Inicio',
      1 => 'Paso 1 — Perfil',
      2 => 'Paso 2 — Servicios',
      3 => 'Paso 3 — Staff',
      4 => 'Paso 4 — Horarios',
      5 => 'Paso 5 — Stripe',
      _ => 'Paso $step',
    };
  }

  String _stripeLabel(String status) {
    return switch (status) {
      'complete' => 'Completado',
      'pending' || 'pending_verification' => 'Pendiente',
      'not_started' => 'Sin iniciar',
      _ => status,
    };
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.emailOk, required this.phoneOk});
  final bool emailOk;
  final bool phoneOk;

  @override
  Widget build(BuildContext context) {
    final both = emailOk && phoneOk;
    final none = !emailOk && !phoneOk;
    final color = both ? Colors.green : (none ? Colors.red : Colors.orange);
    final label = both ? 'Listo' : (none ? 'Ninguno' : 'Parcial');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            both ? Icons.check_circle : Icons.pending,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
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

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.icon,
    required this.label,
    required this.verified,
  });
  final IconData icon;
  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = verified ? Colors.green : Colors.red;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: BCSpacing.sm),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Icon(
          verified ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: color,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
          Icon(Icons.pending, size: 12, color: color),
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
  });

  final IconData icon;
  final String label;
  final String value;

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
      ],
    );
  }
}
