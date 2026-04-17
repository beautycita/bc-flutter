import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_operations_provider.dart';
import '../../providers/admin_payout_holds_provider.dart';
import '../../widgets/web_design_system.dart';

/// CEO Operations Dashboard — system health, business activity, and logs.
///
/// Desktop-first 3-column grid:
/// - Left: System Health (server status, backup, DB, edge functions)
/// - Center: Business Activity (bookings, revenue, signups, disputes)
/// - Right: Alerts & Logs (audit trail, toggle changes, failed payments)
class OperationsDashboardPage extends ConsumerWidget {
  const OperationsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final isMobile = WebBreakpoints.isMobile(width);
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(isMobile: isMobile),
              const SizedBox(height: 24),
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _SystemHealthColumn(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(child: _BusinessActivityColumn(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(child: _AlertsLogsColumn(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _SystemHealthColumn(ref: ref),
                const SizedBox(height: 16),
                _BusinessActivityColumn(ref: ref),
                const SizedBox(height: 16),
                _AlertsLogsColumn(ref: ref),
              ],
              const SizedBox(height: 24),
              const _PayoutHoldsSection(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Page Header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    final formattedDate = dateStr[0].toUpperCase() + dateStr.substring(1);
    final timeStr = DateFormat('HH:mm').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WebSectionHeader(
          label: '$formattedDate  $timeStr',
          title: 'Centro de Operaciones',
          centered: false,
          titleSize: isMobile ? 28 : 36,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Actualizacion automatica cada 30s',
              style: TextStyle(
                fontSize: 11,
                color: kWebTextHint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Left Column: System Health ───────────────────────────────────────────────

class _SystemHealthColumn extends StatelessWidget {
  const _SystemHealthColumn({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthAsync = ref.watch(systemHealthProvider);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dns_outlined, size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                'Salud del Sistema',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: kWebTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          healthAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => _buildHealthContent(
                context, SystemHealth.placeholder, isError: true),
            data: (health) => _buildHealthContent(context, health),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthContent(BuildContext context, SystemHealth health,
      {bool isError = false}) {
    return Column(
      children: [
        // Database status
        _StatusIndicator(
          label: 'Base de datos',
          status: isError
              ? _HealthStatus.red
              : health.databaseOnline
                  ? _HealthStatus.green
                  : _HealthStatus.red,
          detail: health.databaseOnline ? 'Conectada' : 'Sin conexion',
        ),
        const SizedBox(height: 16),

        // Backup status
        _StatusIndicator(
          label: 'Ultimo respaldo',
          status: health.lastBackupAt != null
              ? (DateTime.now().difference(health.lastBackupAt!).inHours < 24
                  ? _HealthStatus.green
                  : _HealthStatus.yellow)
              : _HealthStatus.yellow,
          detail: health.lastBackupAt != null
              ? _formatTimeAgo(health.lastBackupAt!)
              : 'Sin datos',
        ),
        const SizedBox(height: 16),

        // Edge function errors
        _StatusIndicator(
          label: 'Errores edge functions (24h)',
          status: health.edgeFunctionErrors == 0
              ? _HealthStatus.green
              : health.edgeFunctionErrors < 5
                  ? _HealthStatus.yellow
                  : _HealthStatus.red,
          detail: '${health.edgeFunctionErrors} errores',
        ),
        const SizedBox(height: 16),

        // Server uptime indicator
        _StatusIndicator(
          label: 'Servidor',
          status: isError ? _HealthStatus.red : _HealthStatus.green,
          detail: isError ? 'Error de conexion' : 'En linea',
        ),

        const SizedBox(height: 16),

        // Last checked timestamp
        Center(
          child: Text(
            'Actualizado: ${DateFormat('HH:mm:ss').format(health.checkedAt)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: kWebTextHint,
              fontSize: 10,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Monitoring tools
        Row(
          children: [
            Expanded(
              child: WebOutlinedButton(
                onPressed: () {
                  launchUrlString('https://beautycita.com/kuma/');
                },
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monitor_heart_outlined, size: 16, color: kWebPrimary),
                    SizedBox(width: 6),
                    Text('Uptime', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: WebOutlinedButton(
                onPressed: () {
                  launchUrlString('https://beautycita.com/beszel/');
                },
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.memory_outlined, size: 16, color: kWebPrimary),
                    SizedBox(width: 6),
                    Text('Recursos', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return 'Hace ${diff.inDays}d';
  }
}

enum _HealthStatus { green, yellow, red }

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.label,
    required this.status,
    required this.detail,
  });
  final String label;
  final _HealthStatus status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color dotColor, Color bgColor) = switch (status) {
      _HealthStatus.green => (
          const Color(0xFF4CAF50),
          const Color(0xFF4CAF50).withValues(alpha: 0.08),
        ),
      _HealthStatus.yellow => (
          const Color(0xFFFF9800),
          const Color(0xFFFF9800).withValues(alpha: 0.08),
        ),
      _HealthStatus.red => (
          const Color(0xFFE53935),
          const Color(0xFFE53935).withValues(alpha: 0.08),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, color: kWebTextPrimary),
            ),
          ),
          Text(
            detail,
            style: theme.textTheme.labelSmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Center Column: Business Activity ─────────────────────────────────────────

class _BusinessActivityColumn extends StatelessWidget {
  const _BusinessActivityColumn({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(businessActivityProvider);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up_outlined, size: 18, color: kWebSecondary),
              ),
              const SizedBox(width: 10),
              Text(
                'Actividad del Negocio',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: kWebTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          activityAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text('Error al cargar',
                  style: theme.textTheme.bodySmall),
            ),
            data: (activity) => _buildActivityContent(context, activity),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityContent(
      BuildContext context, BusinessActivity activity) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Bookings today header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWebPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kWebCardBorder),
          ),
          child: Column(
            children: [
              Text(
                '${activity.totalBookingsToday}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: kWebPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reservas hoy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // Booking status breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BookingStatusChip(
                    label: 'Confirmadas',
                    count: activity.bookingsConfirmed,
                    color: const Color(0xFF4CAF50),
                  ),
                  _BookingStatusChip(
                    label: 'Pendientes',
                    count: activity.bookingsPending,
                    color: const Color(0xFFFF9800),
                  ),
                  _BookingStatusChip(
                    label: 'Canceladas',
                    count: activity.bookingsCancelled,
                    color: const Color(0xFFE53935),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Revenue today
        _ActivityMetric(
          icon: Icons.payments_outlined,
          label: 'Ingresos hoy',
          value: '\$${_fmtAmount(activity.revenueToday)}',
          iconColor: const Color(0xFF4CAF50),
        ),
        const SizedBox(height: 12),

        // New salons
        _ActivityMetric(
          icon: Icons.store_outlined,
          label: 'Nuevos salones (7 dias)',
          value: '${activity.newSalonsLast7Days}',
          iconColor: const Color(0xFF9C27B0),
        ),
        const SizedBox(height: 12),

        // Active users
        _ActivityMetric(
          icon: Icons.people_outlined,
          label: 'Usuarios activos (24h)',
          value: '${activity.activeUsersLast24h}',
          iconColor: const Color(0xFF2196F3),
        ),
        const SizedBox(height: 12),

        // Pending disputes
        _ActivityMetric(
          icon: Icons.gavel_outlined,
          label: 'Disputas pendientes',
          value: '${activity.pendingDisputes}',
          iconColor: activity.pendingDisputes > 0
              ? const Color(0xFFE53935)
              : const Color(0xFF4CAF50),
          highlight: activity.pendingDisputes > 0,
        ),
      ],
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? iconColor.withValues(alpha: 0.06)
            : kWebBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? iconColor.withValues(alpha: 0.2)
              : kWebCardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500, color: kWebTextPrimary),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? iconColor : kWebTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Right Column: Alerts & Logs ──────────────────────────────────────────────

class _AlertsLogsColumn extends StatelessWidget {
  const _AlertsLogsColumn({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(opsLogsProvider);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebTertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_outlined, size: 18, color: kWebTertiary),
              ),
              const SizedBox(width: 10),
              Text(
                'Alertas y Registro',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: kWebTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          logsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text('Error al cargar registros',
                  style: theme.textTheme.bodySmall),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 40,
                            color: const Color(0xFF4CAF50)
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'Sin eventos recientes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebTextHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Group by type for section headers
              final adminActions =
                  logs.where((l) => l.type == 'admin_action').toList();
              final toggleChanges =
                  logs.where((l) => l.type == 'toggle_change').toList();
              final failedPayments =
                  logs.where((l) => l.type == 'failed_payment').toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (failedPayments.isNotEmpty) ...[
                    _LogSection(
                      title: 'Pagos fallidos',
                      icon: Icons.payment,
                      color: const Color(0xFFE53935),
                      entries: failedPayments.take(5).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (toggleChanges.isNotEmpty) ...[
                    _LogSection(
                      title: 'Cambios de toggles',
                      icon: Icons.toggle_on,
                      color: const Color(0xFFFF9800),
                      entries: toggleChanges.take(5).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (adminActions.isNotEmpty) ...[
                    _LogSection(
                      title: 'Acciones de admin',
                      icon: Icons.admin_panel_settings,
                      color: const Color(0xFF2196F3),
                      entries: adminActions.take(10).toList(),
                    ),
                  ],
                  if (adminActions.isEmpty &&
                      toggleChanges.isEmpty &&
                      failedPayments.isEmpty)
                    // Show all mixed if no typed entries
                    _LogSection(
                      title: 'Registro de actividad',
                      icon: Icons.list_alt_outlined,
                      color: kWebPrimary,
                      entries: logs.take(15).toList(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<OpsLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$title (${entries.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < entries.length; i++) ...[
          _LogRow(entry: entries[i]),
          if (i < entries.length - 1)
            Divider(
              height: 1,
              color: kWebCardBorder.withValues(alpha: 0.5),
            ),
        ],
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});
  final OpsLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (IconData icon, Color color) = switch (entry.type) {
      'failed_payment' => (Icons.error_outlined, const Color(0xFFE53935)),
      'toggle_change' => (Icons.toggle_on_outlined, const Color(0xFFFF9800)),
      'admin_action' => (
          Icons.admin_panel_settings_outlined,
          const Color(0xFF2196F3)
        ),
      _ => (Icons.info_outlined, kWebPrimary),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatTimeAgo(entry.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: kWebTextHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('d/M HH:mm').format(dt);
  }
}

// ── Payout Holds Section ─────────────────────────────────────────────────────

class _PayoutHoldsSection extends ConsumerWidget {
  const _PayoutHoldsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final holdsAsync = ref.watch(activePayoutHoldsProvider);

    return WebCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel, color: kWebPrimary, size: 22),
                const SizedBox(width: 10),
                Text('Pagos detenidos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                holdsAsync.maybeWhen(
                  data: (rows) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rows.isEmpty ? kWebSuccess.withValues(alpha: 0.15) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rows.isEmpty ? 'Ninguno activo' : '${rows.length} activo${rows.length == 1 ? "" : "s"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: rows.isEmpty ? kWebSuccess : const Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(activePayoutHoldsProvider),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Holds abiertos automaticamente por cambios en beneficiary_name, rfc, clabe, stripe_account_id o deriva con Stripe. Liberar requiere una nota justificativa de al menos 10 caracteres.',
              style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary),
            ),
            const SizedBox(height: 16),
            holdsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Error: $e', style: theme.textTheme.bodySmall?.copyWith(color: kWebError)),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No hay holds activos. Todos los salones pueden recibir pagos normalmente.',
                      style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final row in rows) _PayoutHoldRowTile(row: row),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutHoldRowTile extends ConsumerWidget {
  const _PayoutHoldRowTile({required this.row});
  final PayoutHoldRow row;

  String _formatAgo(DateTime then) {
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 30) return 'hace ${diff.inDays}d';
    return DateFormat('d/M').format(then);
  }

  Future<void> _showReleaseDialog(BuildContext context, WidgetRef ref) async {
    final noteController = TextEditingController();
    final err = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Liberar hold'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Negocio: ${row.businessName}'),
              const SizedBox(height: 4),
              Text('Razon: ${row.reasonLabel}'),
              if (row.oldValue != null || row.newValue != null) ...[
                const SizedBox(height: 4),
                Text('Antes: ${row.oldValue ?? "(vacio)"}'),
                Text('Despues: ${row.newValue ?? "(vacio)"}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota justificativa (minimo 10 caracteres)',
                  hintText: 'Ej: Verificado con el salon por teléfono, RFC coincide con nueva ID.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('__cancel__'),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final note = noteController.text.trim();
              if (note.length < 10) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('La nota debe tener al menos 10 caracteres')),
                );
                return;
              }
              final error = await releasePayoutHold(holdId: row.id, note: note);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(error);
            },
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (err == null) {
      ref.invalidate(activePayoutHoldsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hold liberado. Los pagos se reanudaran.')),
        );
      }
    } else if (err != '__cancel__' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al liberar: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWebBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE65100),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.businessName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(row.reasonLabel, style: theme.textTheme.bodySmall),
                if ((row.oldValue ?? '').isNotEmpty || (row.newValue ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${row.oldValue ?? "(vacio)"} → ${row.newValue ?? "(vacio)"}',
                    style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Abierto ${_formatAgo(row.startedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: kWebTextHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _showReleaseDialog(context, ref),
            icon: const Icon(Icons.lock_open_outlined, size: 16),
            label: const Text('Liberar'),
          ),
        ],
      ),
    );
  }
}

// ── Utility ──────────────────────────────────────────────────────────────────

String _fmtAmount(double amount) {
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
  return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
}
