import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../providers/admin_operations_provider.dart';
import '../../services/supabase_client.dart';

class AdminOperationsDashboardScreen extends ConsumerWidget {
  const AdminOperationsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(systemHealthProvider);
    final activityAsync = ref.watch(businessActivityProvider);
    final logsAsync = ref.watch(opsLogsProvider);
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(systemHealthProvider);
        ref.invalidate(businessActivityProvider);
        ref.invalidate(opsLogsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          Text(
            'Operaciones',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Centro de operaciones de la plataforma',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // ── System status ──
          healthAsync.when(
            data: (health) => _SystemStatusCard(health: health),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Data Enrichment Pipeline ──
          const _EnrichmentPanel(),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Platform KPIs ──
          activityAsync.when(
            data: (activity) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actividad del Dia',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppConstants.paddingSM,
                  crossAxisSpacing: AppConstants.paddingSM,
                  childAspectRatio: 1.5,
                  children: [
                    _KpiCard(
                      label: 'Citas Hoy',
                      value: '${activity.totalBookingsToday}',
                      subtitle: '${activity.bookingsConfirmed} confirmadas',
                      icon: Icons.calendar_today,
                      color: colors.primary,
                    ),
                    _KpiCard(
                      label: 'Usuarios Activos',
                      value: '${activity.activeUsersLast24h}',
                      subtitle: 'Ultimas 24h',
                      icon: Icons.people,
                      color: const Color(0xFF06B6D4),
                    ),
                    _KpiCard(
                      label: 'Disputas',
                      value: '${activity.pendingDisputes}',
                      subtitle: 'Pendientes',
                      icon: Icons.gavel,
                      color: activity.pendingDisputes > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                    _KpiCard(
                      label: 'Nuevos Salones',
                      value: '${activity.newSalonsLast7Days}',
                      subtitle: 'Ultimos 7 dias',
                      icon: Icons.store,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSM),

                // Booking breakdown row
                _BookingBreakdownCard(activity: activity),
              ],
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Activity feed ──
          Text(
            'Actividad Reciente',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF212121),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return _EmptyCard(message: 'Sin actividad reciente');
              }
              return Column(
                children: logs.map((log) => _ActivityTile(entry: log)).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Infrastructure tools ──
          Text(
            'INFRAESTRUCTURA',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Row(
            children: [
              Expanded(
                child: _InfraCard(
                  icon: Icons.monitor_heart_outlined,
                  label: 'Estado del Sistema',
                  subtitle: 'Health checks y uptime',
                  color: const Color(0xFF059669),
                  onTap: () => context.push(AppRoutes.systemStatus),
                  statusWidget: healthAsync.when(
                    data: (health) {
                      final ok = health.databaseOnline &&
                          health.edgeFunctionErrors == 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ok
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (ok
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFDC2626))
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ok ? 'Operativo' : 'Alerta',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ok
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    error: (_, _) => const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: _InfraCard(
                  icon: Icons.dashboard_rounded,
                  label: 'Grafana',
                  subtitle: 'Metricas y dashboards',
                  color: const Color(0xFFF46800),
                  onTap: () => launchUrl(
                    Uri.parse(
                        'https://beautycita.com/grafana/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingXL),
        ],
      ),
    );
  }
}

// ── Widget components ────────────────────────────────────────────────────────

class _SystemStatusCard extends StatelessWidget {
  final SystemHealth health;
  const _SystemStatusCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final isHealthy = health.databaseOnline && health.edgeFunctionErrors == 0;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: isHealthy
              ? const Color(0xFF059669).withValues(alpha: 0.3)
              : const Color(0xFFDC2626).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.error,
                color: isHealthy
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isHealthy ? 'Sistema Operativo' : 'Atencion Requerida',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isHealthy
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Base de datos',
            status: health.databaseOnline ? 'Online' : 'Offline',
            ok: health.databaseOnline,
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: 'Errores Edge (24h)',
            status: '${health.edgeFunctionErrors}',
            ok: health.edgeFunctionErrors == 0,
          ),
          if (health.lastBackupAt != null) ...[
            const SizedBox(height: 6),
            _StatusRow(
              label: 'Ultimo backup',
              status: DateFormat('dd/MM HH:mm').format(health.lastBackupAt!),
              ok: health.lastBackupStatus == 'success',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final bool ok;

  const _StatusRow({
    required this.label,
    required this.status,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: const Color(0xFF616161),
          ),
        ),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingSM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF757575),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF212121),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: const Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBreakdownCard extends StatelessWidget {
  final BusinessActivity activity;
  const _BookingBreakdownCard({required this.activity});

  static final _mxn = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _BookingStat(
            label: 'Confirmadas',
            value: '${activity.bookingsConfirmed}',
            color: const Color(0xFF059669),
          ),
          _BookingStat(
            label: 'Pendientes',
            value: '${activity.bookingsPending}',
            color: const Color(0xFFF59E0B),
          ),
          _BookingStat(
            label: 'Canceladas',
            value: '${activity.bookingsCancelled}',
            color: const Color(0xFFDC2626),
          ),
          _BookingStat(
            label: 'Ingresos',
            value: _mxn.format(activity.revenueToday),
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }
}

class _BookingStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BookingStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final OpsLogEntry entry;
  const _ActivityTile({required this.entry});

  static final _timeFmt = DateFormat('dd/MM HH:mm');

  IconData get _icon {
    switch (entry.type) {
      case 'toggle_change':
        return Icons.toggle_on;
      case 'failed_payment':
        return Icons.payment;
      default:
        return Icons.admin_panel_settings;
    }
  }

  Color get _color {
    switch (entry.type) {
      case 'toggle_change':
        return const Color(0xFF8B5CF6);
      case 'failed_payment':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF06B6D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppConstants.paddingSM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 16, color: _color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _timeFmt.format(entry.timestamp),
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFFDC2626)),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF9E9E9E)),
        ),
      ),
    );
  }
}

class _InfraCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? statusWidget;

  const _InfraCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.statusWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: const Color(0xFF9E9E9E),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              if (statusWidget != null) ...[
                const SizedBox(height: 10),
                statusWidget!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data Enrichment Pipeline ─────────────────────────────────────────────────

class _EnrichmentPanel extends StatefulWidget {
  const _EnrichmentPanel();

  @override
  State<_EnrichmentPanel> createState() => _EnrichmentPanelState();
}

class _EnrichmentPanelState extends State<_EnrichmentPanel> {
  bool _running = false;
  String _status = '';
  String _currentAction = '';

  Future<void> _runAction(String action) async {
    setState(() {
      _running = true;
      _currentAction = action;
      _status = 'Ejecutando $action...';
    });

    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'enrich-discovered-salons',
        body: {'action': action, 'batch_size': 50},
      );

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        final processed = data['processed'] ?? data['merged'] ?? 0;
        final remaining = data['remaining'] ?? '?';
        setState(() {
          _status = '$action: $processed procesados, $remaining restantes';
        });
      } else {
        setState(() {
          _status = 'Error: ${response.data}';
        });
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enriquecimiento de Datos',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Geocodificacion, deduplicacion y categorizacion de salones descubiertos',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EnrichButton(
                  label: 'Geocodificar',
                  icon: Icons.location_on_outlined,
                  running: _running && _currentAction == 'geocode',
                  onTap: _running ? null : () => _runAction('geocode'),
                ),
                _EnrichButton(
                  label: 'Deduplicar',
                  icon: Icons.merge_outlined,
                  running: _running && _currentAction == 'dedup',
                  onTap: _running ? null : () => _runAction('dedup'),
                ),
                _EnrichButton(
                  label: 'Categorizar',
                  icon: Icons.category_outlined,
                  running: _running && _currentAction == 'categorize',
                  onTap: _running ? null : () => _runAction('categorize'),
                ),
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Text(
                _status,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _status.startsWith('Error')
                      ? colors.error
                      : colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnrichButton extends StatelessWidget {
  const _EnrichButton({
    required this.label,
    required this.icon,
    required this.running,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final bool running;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: running
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
