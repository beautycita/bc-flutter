import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(businessStatsProvider);
    final colors = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final todayAppts = ref.watch(
      businessAppointmentsProvider((start: todayStart, end: todayEnd)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(businessStatsProvider);
        ref.invalidate(currentBusinessProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Stats grid
          statsAsync.when(
            data: (stats) => _StatsGrid(stats: stats),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                child: Text('Error cargando estadisticas',
                    style: GoogleFonts.nunito(color: colors.error)),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Today's appointments
          Text(
            'Citas de Hoy',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          todayAppts.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return Card(
                  elevation: 0,
                  color: colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingXL),
                    child: Column(
                      children: [
                        Icon(Icons.event_available_rounded,
                            size: 48,
                            color: colors.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: AppConstants.paddingSM),
                        Text(
                          'No hay citas para hoy',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: appointments.take(5).map((appt) {
                  return _AppointmentCard(appointment: appt);
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final BusinessStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.paddingSM,
      mainAxisSpacing: AppConstants.paddingSM,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Hoy',
          value: '${stats.appointmentsToday}',
          color: colors.primary,
        ),
        _StatCard(
          icon: Icons.date_range_rounded,
          label: 'Esta Semana',
          value: '${stats.appointmentsWeek}',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.attach_money_rounded,
          label: 'Ingresos Mes',
          value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Por Confirmar',
          value: '${stats.pendingConfirmations}',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.star_rounded,
          label: 'Calificacion',
          value: stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '--',
          color: Colors.amber,
        ),
        _StatCard(
          icon: Icons.reviews_rounded,
          label: 'Resenas',
          value: '${stats.totalReviews}',
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = appointment['status'] as String? ?? 'pending';
    final service = appointment['service_name'] as String? ?? 'Servicio';
    final startsAt = appointment['starts_at'] as String?;
    final price = (appointment['price'] as num?)?.toDouble() ?? 0;

    String timeStr = '';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt);
      if (dt != null) {
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    final statusColor = _statusColor(status);

    return Card(
      elevation: 0,
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
          child: Center(
            child: Text(
              timeStr,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ),
        title: Text(
          service,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          _statusLabel(status),
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Text(
          '\$${price.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled_customer':
      case 'cancelled_business':
        return Colors.red;
      case 'no_show':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'completed':
        return 'Completada';
      case 'cancelled_customer':
        return 'Cancelada (cliente)';
      case 'cancelled_business':
        return 'Cancelada (negocio)';
      case 'no_show':
        return 'No asistio';
      default:
        return status;
    }
  }
}
