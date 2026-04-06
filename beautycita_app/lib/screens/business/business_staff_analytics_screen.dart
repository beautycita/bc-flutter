import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
// ignore: depend_on_referenced_packages
import 'package:beautycita/widgets/admin/admin_widgets.dart';

/// Staff productivity analytics panel for the business portal.
class BusinessStaffAnalyticsScreen extends ConsumerStatefulWidget {
  const BusinessStaffAnalyticsScreen({super.key});

  @override
  ConsumerState<BusinessStaffAnalyticsScreen> createState() =>
      _BusinessStaffAnalyticsScreenState();
}

class _BusinessStaffAnalyticsScreenState
    extends ConsumerState<BusinessStaffAnalyticsScreen> {
  String _period = 'week';

  Widget _exportButton(BuildContext context) {
    final dataAsync = ref.watch(staffProductivityProvider(_period));
    return dataAsync.maybeWhen(
      data: (data) => IconButton(
        icon: const Icon(Icons.download_rounded, size: 20),
        tooltip: 'Exportar CSV',
        color: Theme.of(context).colorScheme.primary,
        onPressed: () => _exportStaffCsv(context, data),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _exportStaffCsv(BuildContext context, StaffProductivityData data) {
    CsvExporter.export<StaffProductivityEntry>(
      context: context,
      filename: 'rendimiento_staff',
      columns: [
        CsvColumn('Nombre', (e) => e.firstName),
        CsvColumn('Ingresos', (e) => e.revenue.toStringAsFixed(2)),
        CsvColumn('Citas', (e) => e.completedAppointments.toString()),
        CsvColumn('Horas', (e) => e.hoursWorked.toStringAsFixed(1)),
        CsvColumn('Rating', (e) => e.allTimeRating > 0 ? e.allTimeRating.toStringAsFixed(1) : ''),
        CsvColumn('No-Shows', (e) => e.noShows.toString()),
      ],
      items: data.entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(staffProductivityProvider(_period));

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: Colors.white,
      onRefresh: () async =>
          ref.invalidate(staffProductivityProvider(_period)),
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Period selector
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rendimiento del Equipo',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121),
                  ),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Semana')),
                  ButtonSegment(value: 'month', label: Text('Mes')),
                ],
                selected: {_period},
                onSelectionChanged: (v) =>
                    setState(() => _period = v.first),
                style: SegmentedButton.styleFrom(
                  textStyle: GoogleFonts.nunito(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              _exportButton(context),
            ],
          ),

          const SizedBox(height: AppConstants.paddingMD),

          dataAsync.when(
            data: (data) {
              if (data.entries.isEmpty) {
                return _EmptyState();
              }
              return Column(
                children: [
                  // Highlight cards row
                  _HighlightCards(data: data),
                  const SizedBox(height: AppConstants.paddingMD),

                  // Revenue breakdown bar chart
                  _RevenueChart(data: data),
                  const SizedBox(height: AppConstants.paddingMD),

                  // Revenue TrendChart (sorted by revenue)
                  _StaffRevenueTrendChart(data: data),
                  const SizedBox(height: AppConstants.paddingMD),

                  // Hours breakdown
                  _HoursChart(data: data, period: _period),
                  const SizedBox(height: AppConstants.paddingMD),

                  // Staff ranking table
                  _StaffRankingTable(data: data),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error: $e',
                    style: GoogleFonts.nunito(color: colors.error)),
              ),
            ),
          ),

          // ── Service Revenue Breakdown ──
          const SizedBox(height: AppConstants.paddingLG),
          _ServiceRevenueSection(),

          // ── Comisiones ──
          const SizedBox(height: AppConstants.paddingLG),
          const _CommissionsSection(),
        ],
      ),
    );
  }
}

// -- Service revenue breakdown --

class _ServiceRevenueSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final monthData = ref.watch(serviceRevenueProvider('month'));
    final fmt = NumberFormat('#,##0', 'es_MX');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.pie_chart_outline, size: 20, color: Color(0xFFEC4899)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Ingresos por Servicio',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            // Export
            monthData.maybeWhen(
              data: (data) => IconButton(
                icon: const Icon(Icons.download_rounded, size: 20),
                color: colors.primary,
                onPressed: () => CsvExporter.export<ServiceRevenueEntry>(
                  context: context,
                  filename: 'ingresos_servicios',
                  columns: [
                    CsvColumn('Servicio', (e) => e.serviceName),
                    CsvColumn('Citas', (e) => e.bookings.toString()),
                    CsvColumn('Ingresos', (e) => e.revenue.toStringAsFixed(2)),
                    CsvColumn('Precio Promedio', (e) => e.avgPrice.toStringAsFixed(2)),
                  ],
                  items: data,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        monthData.when(
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
          data: (services) {
            if (services.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Sin datos de servicios este mes',
                    style: GoogleFonts.nunito(color: colors.onSurface.withValues(alpha: 0.5))),
              );
            }

            // Bar chart
            final chartData = services.take(8).map((s) =>
                TrendPoint(s.serviceName.length > 12 ? '${s.serviceName.substring(0, 10)}..' : s.serviceName, s.revenue)).toList();

            final totalRevenue = services.fold(0.0, (sum, s) => sum + s.revenue);

            return Column(
              children: [
                TrendChart(
                  data: chartData,
                  type: TrendChartType.bar,
                  color: const Color(0xFFEC4899),
                  height: 160,
                  valuePrefix: '\$',
                ),
                const SizedBox(height: 12),

                // Service rows
                ...services.map((s) {
                  final pct = totalRevenue > 0 ? (s.revenue / totalRevenue * 100) : 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.serviceName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${s.bookings} citas · promedio \$${fmt.format(s.avgPrice)}',
                                  style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${fmt.format(s.revenue)}',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                            Text('${pct.toStringAsFixed(1)}%',
                                style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}

// -- Commissions section --

class _CommissionsSection extends ConsumerWidget {
  const _CommissionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final commissionsAsync = ref.watch(staffCommissionsProvider);
    final fmt = NumberFormat('#,##0.00', 'es_MX');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.percent_rounded,
                  size: 20, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comisiones',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('Mes actual',
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: colors.primary,
              onPressed: () => ref.invalidate(staffCommissionsProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),

        commissionsAsync.when(
          loading: () => const SizedBox(
              height: 80,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Text('Error: $e',
              style: GoogleFonts.nunito(color: colors.error)),
          data: (data) {
            if (data.entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMD),
                  border: Border.all(
                      color: colors.outline.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.percent_rounded,
                        size: 36,
                        color: colors.primary.withValues(alpha: 0.2)),
                    const SizedBox(height: 8),
                    Text('Sin comisiones este mes',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF757575))),
                    const SizedBox(height: 4),
                    Text(
                        'Asigna un % de comision a tu personal para empezar.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: const Color(0xFF9E9E9E))),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Summary totals row
                Row(
                  children: [
                    Expanded(
                      child: _CommissionSummaryCard(
                        label: 'Por pagar',
                        amount: data.totalPending,
                        color: const Color(0xFFFF8F00),
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CommissionSummaryCard(
                        label: 'Pagado',
                        amount: data.totalPaid,
                        color: const Color(0xFF059669),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CommissionSummaryCard(
                        label: 'Total mes',
                        amount: data.totalMonth,
                        color: colors.primary,
                        icon: Icons.summarize_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Per-staff rows
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(
                        color: colors.outline.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.entries.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CommissionStaffRow(
                          entry: data.entries[i],
                          fmt: fmt,
                          colors: colors,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CommissionSummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _CommissionSummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_MX');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9E9E9E)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('\$${fmt.format(amount)}',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

class _CommissionStaffRow extends ConsumerStatefulWidget {
  final StaffCommissionSummary entry;
  final NumberFormat fmt;
  final ColorScheme colors;

  const _CommissionStaffRow({
    required this.entry,
    required this.fmt,
    required this.colors,
  });

  @override
  ConsumerState<_CommissionStaffRow> createState() =>
      _CommissionStaffRowState();
}

class _CommissionStaffRowState
    extends ConsumerState<_CommissionStaffRow> {
  bool _marking = false;

  Future<void> _confirmAndMarkPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final fmt = NumberFormat('#,##0.00', 'es_MX');
        return AlertDialog(
          title: Text('Marcar como pagado',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          content: Text(
            'Confirmar pago de \$${fmt.format(widget.entry.pendingAmount)} '
            'a ${widget.entry.firstName}?\n\n'
            '${widget.entry.pendingCount} comisiones pendientes seran marcadas como pagadas.',
            style: GoogleFonts.nunito(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(
                      color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Marcar como pagado',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _markPaid();
  }

  Future<void> _markPaid() async {
    setState(() => _marking = true);
    try {
      final bizAsync = ref.read(currentBusinessProvider);
      final bizId = bizAsync.valueOrNull?['id'] as String?;
      if (bizId == null) return;

      await SupabaseClientService.client
          .from('staff_commissions')
          .update({'status': 'paid', 'paid_at': DateTime.now().toIso8601String()})
          .eq('staff_id', widget.entry.staffId)
          .eq('business_id', bizId)
          .eq('status', 'pending');

      ref.invalidate(staffCommissionsProvider);
      ToastService.showSuccess('Comision marcada como pagada');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(
          ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final fmt = widget.fmt;
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Avatar initial
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            child: Text(
              entry.firstName.isNotEmpty
                  ? entry.firstName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: colors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.firstName,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${entry.pendingCount + entry.paidCount} citas'
                  '${entry.pendingCount > 0 ? ' · ${entry.pendingCount} pendientes' : ''}',
                  style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (entry.pendingAmount > 0)
                Text('\$${fmt.format(entry.pendingAmount)}',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF8F00))),
              if (entry.paidAmount > 0)
                Text('\$${fmt.format(entry.paidAmount)} pagado',
                    style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: const Color(0xFF059669))),
            ],
          ),
          if (entry.pendingAmount > 0) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: _marking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF059669),
                      ),
                      onPressed: _confirmAndMarkPaid,
                      child: Text('Pagar',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// -- Empty state --

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined,
              size: 48, color: colors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Sin datos de productividad',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF757575),
              )),
          const SizedBox(height: 4),
          Text('Agrega staff y completa citas para ver metricas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: const Color(0xFF9E9E9E),
              )),
        ],
      ),
    );
  }
}

// -- Highlight cards (top earner, most reviews, most booked) --

class _HighlightCards extends StatelessWidget {
  final StaffProductivityData data;
  const _HighlightCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final topEarner = data.topEarner;
    final mostReviewed = data.mostReviewed;
    final mostBooked = data.mostBooked;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HighlightCard(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFB300),
                title: 'Top Ingresos',
                staffName: topEarner?.firstName ?? '-',
                value: '\$${topEarner?.revenue.toStringAsFixed(0) ?? '0'}',
                subtitle: '${topEarner?.completedAppointments ?? 0} citas',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HighlightCard(
                icon: Icons.reviews_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: 'Mas Resenas',
                staffName: mostReviewed?.firstName ?? '-',
                value: '${mostReviewed?.reviewCount ?? 0}',
                subtitle: mostReviewed != null && mostReviewed.avgRating > 0
                    ? '${mostReviewed.avgRating.toStringAsFixed(1)} avg'
                    : '-',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HighlightCard(
                icon: Icons.event_available_rounded,
                iconColor: const Color(0xFF42A5F5),
                title: 'Mas Citas',
                staffName: mostBooked?.firstName ?? '-',
                value: '${mostBooked?.totalAppointments ?? 0}',
                subtitle: '${mostBooked?.hoursWorked.toStringAsFixed(1) ?? '0'}h',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String staffName;
  final String value;
  final String subtitle;

  const _HighlightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.staffName,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.06),
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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(staffName,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: iconColor,
              )),
          Text(subtitle,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: const Color(0xFF757575),
              )),
        ],
      ),
    );
  }
}

// -- Revenue per staff bar chart --

class _RevenueChart extends StatelessWidget {
  final StaffProductivityData data;
  const _RevenueChart({required this.data});

  static const _staffColors = [
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
    Color(0xFFFF8F00), Color(0xFF8E24AA), Color(0xFF00ACC1),
    Color(0xFFD81B60), Color(0xFF5D4037),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sorted = [...data.entries]
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final maxRevenue = sorted.isEmpty
        ? 1.0
        : math.max(sorted.first.revenue, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ingresos por Estilista',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              )),
          Text('Total: \$${data.totalRevenue.toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF757575),
              )),
          const SizedBox(height: 12),
          for (var i = 0; i < sorted.length; i++)
            _RevenueBar(
              name: sorted[i].firstName,
              revenue: sorted[i].revenue,
              maxRevenue: maxRevenue,
              color: _staffColors[i % _staffColors.length],
            ),
        ],
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  final String name;
  final double revenue;
  final double maxRevenue;
  final Color color;

  const _RevenueBar({
    required this.name,
    required this.revenue,
    required this.maxRevenue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = revenue / maxRevenue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(name,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF424242),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.02, 1.0),
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 6),
                    child: fraction > 0.2
                        ? Text('\$${revenue.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ))
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (fraction <= 0.2)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('\$${revenue.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
            ),
        ],
      ),
    );
  }
}

// -- Hours chart (daily breakdown) --

class _HoursChart extends StatelessWidget {
  final StaffProductivityData data;
  final String period;
  const _HoursChart({required this.data, required this.period});

  static const _dayLabels = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
  static const _staffColors = [
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
    Color(0xFFFF8F00), Color(0xFF8E24AA), Color(0xFF00ACC1),
    Color(0xFFD81B60), Color(0xFF5D4037),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Horas Trabajadas',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              )),
          Text('Total: ${data.totalHours.toStringAsFixed(1)}h',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF757575),
              )),
          const SizedBox(height: 12),

          // Per-staff hours summary
          for (var i = 0; i < data.entries.length; i++)
            _HoursRow(
              entry: data.entries[i],
              color: _staffColors[i % _staffColors.length],
            ),

          const SizedBox(height: 12),

          // Weekly hours breakdown (stacked per day)
          Text('Distribucion semanal',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF757575),
              )),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (dayIdx) {
                final weekday = dayIdx + 1; // 1=Mon
                double totalForDay = 0;
                for (final e in data.entries) {
                  totalForDay += e.dailyHours[weekday] ?? 0;
                }
                return Expanded(
                  child: _DayBar(
                    label: _dayLabels[dayIdx],
                    hours: totalForDay,
                    maxHours: _maxDayHours(),
                    color: colors.primary,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  double _maxDayHours() {
    double maxH = 1;
    for (int d = 1; d <= 7; d++) {
      double dayTotal = 0;
      for (final e in data.entries) {
        dayTotal += e.dailyHours[d] ?? 0;
      }
      if (dayTotal > maxH) maxH = dayTotal;
    }
    return maxH;
  }
}

class _HoursRow extends StatelessWidget {
  final StaffProductivityEntry entry;
  final Color color;
  const _HoursRow({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    final dailyAvg = entry.hoursWorked > 0
        ? entry.hoursWorked /
            entry.dailyHours.keys.length.clamp(1, 7)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: Text(entry.firstName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.hoursWorked.toStringAsFixed(1)}h total  |  ${dailyAvg.toStringAsFixed(1)}h/dia',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String label;
  final double hours;
  final double maxHours;
  final Color color;

  const _DayBar({
    required this.label,
    required this.hours,
    required this.maxHours,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barMaxH = 70.0;
    final barH = maxHours > 0 ? (hours / maxHours) * barMaxH : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hours > 0)
            Text(hours.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          Container(
            height: math.max(barH, hours > 0 ? 4 : 0),
            width: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: hours > 0 ? 0.7 : 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: const Color(0xFF9E9E9E),
              )),
        ],
      ),
    );
  }
}

// -- Staff ranking table --

class _StaffRankingTable extends StatelessWidget {
  final StaffProductivityData data;
  const _StaffRankingTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sorted = [...data.entries]
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ranking del Equipo',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              )),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              const SizedBox(width: 24), // rank
              Expanded(
                flex: 3,
                child: Text('Nombre',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    )),
              ),
              Expanded(
                flex: 2,
                child: Text('Citas',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    )),
              ),
              Expanded(
                flex: 2,
                child: Text('Ingresos',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    )),
              ),
              Expanded(
                flex: 2,
                child: Text('Horas',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    )),
              ),
              Expanded(
                flex: 2,
                child: Text('Rating',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    )),
              ),
            ],
          ),
          const Divider(height: 16),

          for (var i = 0; i < sorted.length; i++)
            _RankingRow(entry: sorted[i], rank: i + 1),
        ],
      ),
    );
  }
}

// -- Staff revenue TrendChart (bar chart) --

class _StaffRevenueTrendChart extends StatelessWidget {
  final StaffProductivityData data;
  const _StaffRevenueTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sorted = [...data.entries]
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    if (sorted.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: TrendChart(
        title: 'Ingresos por Estilista',
        type: TrendChartType.bar,
        color: colors.primary,
        height: 160,
        valuePrefix: '\$',
        data: sorted.map((e) => TrendPoint(e.firstName, e.revenue)).toList(),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final StaffProductivityEntry entry;
  final int rank;
  const _RankingRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: rank <= 3
                ? Icon(
                    Icons.emoji_events_rounded,
                    size: 16,
                    color: rank == 1
                        ? const Color(0xFFFFB300)
                        : rank == 2
                            ? const Color(0xFF90A4AE)
                            : const Color(0xFFBF8040),
                  )
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    )),
          ),
          Expanded(
            flex: 3,
            child: Text(entry.firstName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text('${entry.completedAppointments}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    )),
                if (entry.noShows > 0)
                  Text('${entry.noShows} NS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        color: const Color(0xFFEF5350),
                      )),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('\$${entry.revenue.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4CAF50),
                )),
          ),
          Expanded(
            flex: 2,
            child: Text('${entry.hoursWorked.toStringAsFixed(1)}h',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF424242),
                )),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    size: 12,
                    color: entry.allTimeRating > 0
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFE0E0E0)),
                const SizedBox(width: 2),
                Text(
                  entry.allTimeRating > 0
                      ? entry.allTimeRating.toStringAsFixed(1)
                      : '-',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF424242),
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
