import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_operations_provider.dart';

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
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    final formattedDate = dateStr[0].toUpperCase() + dateStr.substring(1);
    final timeStr = DateFormat('HH:mm').format(now);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined,
                  size: 24, color: theme.colorScheme.primary),
              const SizedBox(width: BCSpacing.sm),
              Text(
                'Centro de Operaciones',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$formattedDate  $timeStr',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.monitor_heart_outlined,
            size: 28, color: theme.colorScheme.primary),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Text(
            'Centro de Operaciones',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$formattedDate  $timeStr',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
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
    final colors = theme.colorScheme;
    final healthAsync = ref.watch(systemHealthProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Salud del Sistema',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
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

        const SizedBox(height: 24),

        // Grafana dashboards link
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Abrir Grafana'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          onPressed: () {
            launchUrlString('https://beautycita.com/grafana/');
          },
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
    final colors = theme.colorScheme;

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
        borderRadius: BorderRadius.circular(8),
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
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            detail,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
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
    final colors = theme.colorScheme;
    final activityAsync = ref.watch(businessActivityProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Actividad del Negocio',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
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
    final colors = theme.colorScheme;

    return Column(
      children: [
        // Bookings today header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '${activity.totalBookingsToday}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reservas hoy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
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
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? iconColor.withValues(alpha: 0.06)
            : colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: iconColor.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? iconColor : null,
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
    final colors = theme.colorScheme;
    final logsAsync = ref.watch(opsLogsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Alertas y Registro',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
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
                            color:
                                colors.onSurface.withValues(alpha: 0.4),
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
                      icon: Icons.list_alt,
                      color: colors.primary,
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
    final colors = theme.colorScheme;

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
              color: colors.outlineVariant.withValues(alpha: 0.5),
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
    final colors = theme.colorScheme;

    final (IconData icon, Color color) = switch (entry.type) {
      'failed_payment' => (Icons.error_outline, const Color(0xFFE53935)),
      'toggle_change' => (Icons.toggle_on, const Color(0xFFFF9800)),
      'admin_action' => (
          Icons.admin_panel_settings_outlined,
          const Color(0xFF2196F3)
        ),
      _ => (Icons.info_outline, colors.primary),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
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
                    color: colors.onSurface.withValues(alpha: 0.4),
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

// ── Utility ──────────────────────────────────────────────────────────────────

String _fmtAmount(double amount) {
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
  return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
}
