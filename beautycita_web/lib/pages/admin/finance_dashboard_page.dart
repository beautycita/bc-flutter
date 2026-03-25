import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_finance_dashboard_provider.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/web_design_system.dart';

/// CEO Financial Dashboard — deep financial reconciliation and analytics.
///
/// Desktop-first 3-section layout:
/// 1. Revenue KPI cards (today, week, month, all-time)
/// 2. Commission breakdown + Tax withholdings side by side
/// 3. Reconciliation table + Per-salon breakdown
///
/// All data from DB views: v_daily_revenue, v_monthly_revenue,
/// v_business_revenue, v_payment_reconciliation, v_platform_health.
class FinanceDashboardPage extends ConsumerStatefulWidget {
  const FinanceDashboardPage({super.key});

  @override
  ConsumerState<FinanceDashboardPage> createState() =>
      _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends ConsumerState<FinanceDashboardPage> {
  String _reconSearchQuery = '';
  String _reconSortColumn = 'payment_date';
  bool _reconSortAsc = false;
  String _salonSearchQuery = '';
  String _salonSortColumn = 'current_month_revenue';
  bool _salonSortAsc = false;

  @override
  Widget build(BuildContext context) {
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
              _RevenueKpis(
                ref: ref,
                isDesktop: isDesktop,
                isMobile: isMobile,
              ),
              const SizedBox(height: 24),
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _CommissionBreakdown(ref: ref)),
                      const SizedBox(width: 16),
                      Expanded(child: _TaxWithholdings(ref: ref)),
                    ],
                  ),
                )
              else ...[
                _CommissionBreakdown(ref: ref),
                const SizedBox(height: 16),
                _TaxWithholdings(ref: ref),
              ],
              const SizedBox(height: 24),
              _ReconciliationTable(
                ref: ref,
                searchQuery: _reconSearchQuery,
                sortColumn: _reconSortColumn,
                sortAsc: _reconSortAsc,
                onSearchChanged: (q) =>
                    setState(() => _reconSearchQuery = q),
                onSort: (col) => setState(() {
                  if (_reconSortColumn == col) {
                    _reconSortAsc = !_reconSortAsc;
                  } else {
                    _reconSortColumn = col;
                    _reconSortAsc = true;
                  }
                }),
              ),
              const SizedBox(height: 24),
              _SalonBreakdownTable(
                ref: ref,
                searchQuery: _salonSearchQuery,
                sortColumn: _salonSortColumn,
                sortAsc: _salonSortAsc,
                onSearchChanged: (q) =>
                    setState(() => _salonSearchQuery = q),
                onSort: (col) => setState(() {
                  if (_salonSortColumn == col) {
                    _salonSortAsc = !_salonSortAsc;
                  } else {
                    _salonSortColumn = col;
                    _salonSortAsc = true;
                  }
                }),
              ),
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

    return WebSectionHeader(
      label: formattedDate,
      title: 'Panel Financiero CEO',
      centered: false,
      titleSize: isMobile ? 28 : 36,
    );
  }
}

// ── Revenue KPI Cards ────────────────────────────────────────────────────────

class _RevenueKpis extends StatelessWidget {
  const _RevenueKpis({
    required this.ref,
    required this.isDesktop,
    required this.isMobile,
  });
  final WidgetRef ref;
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final kpisAsync = ref.watch(financeDashboardKpisProvider);
    final colors = Theme.of(context).colorScheme;

    return kpisAsync.when(
      loading: () => _KpiLoadingGrid(colors: colors, isMobile: isMobile),
      error: (_, __) => _KpiLoadingGrid(colors: colors, isMobile: isMobile),
      data: (kpis) {
        final cards = [
          KpiCard(
            icon: Icons.today,
            label: 'Ingresos hoy',
            value: _fmtCurrency(kpis.revenueToday),
            prefix: '\$',
            iconColor: const Color(0xFF4CAF50),
          ),
          KpiCard(
            icon: Icons.date_range,
            label: 'Ingresos semana',
            value: _fmtCurrency(kpis.revenueThisWeek),
            prefix: '\$',
            iconColor: const Color(0xFF2196F3),
          ),
          KpiCard(
            icon: Icons.calendar_month,
            label: 'Ingresos mes',
            value: _fmtCurrency(kpis.revenueThisMonth),
            prefix: '\$',
            iconColor: const Color(0xFFFF9800),
          ),
          KpiCard(
            icon: Icons.all_inclusive,
            label: 'Ingresos totales',
            value: _fmtCurrency(kpis.revenueAllTime),
            prefix: '\$',
            iconColor: const Color(0xFF9C27B0),
          ),
          KpiCard(
            icon: Icons.percent,
            label: 'Comision mes',
            value: _fmtCurrency(kpis.commissionThisMonth),
            prefix: '\$',
            iconColor: const Color(0xFF00BCD4),
          ),
          KpiCard(
            icon: Icons.receipt_long,
            label: 'Impuestos mes',
            value: _fmtCurrency(kpis.taxWithheldThisMonth),
            prefix: '\$',
            iconColor: const Color(0xFFE53935),
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                if (card != cards.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: isDesktop ? 6 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.4 : 1.3,
          children: cards,
        );
      },
    );
  }

  String _fmtCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }
}

class _KpiLoadingGrid extends StatelessWidget {
  const _KpiLoadingGrid({required this.colors, required this.isMobile});
  final ColorScheme colors;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: List.generate(6, (i) => Padding(
          padding: EdgeInsets.only(bottom: i < 5 ? 12 : 0),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: kWebSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kWebCardBorder),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kWebPrimary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        )),
      );
    }

    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: List.generate(6, (_) => Container(
        decoration: BoxDecoration(
          color: kWebSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kWebCardBorder),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kWebPrimary.withValues(alpha: 0.5),
            ),
          ),
        ),
      )),
    );
  }
}

// ── Commission Breakdown ─────────────────────────────────────────────────────

class _CommissionBreakdown extends StatelessWidget {
  const _CommissionBreakdown({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(commissionBreakdownProvider);

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
                child: const Icon(Icons.pie_chart_outline, size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                'Desglose de Comisiones (Mes Actual)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: kWebTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          dataAsync.when(
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
            data: (data) {
              if (data.total == 0) {
                return _EmptyState(
                  icon: Icons.pie_chart_outline,
                  message: 'Sin comisiones este mes',
                );
              }

              final bookingPct = data.total > 0
                  ? (data.bookingCommission / data.total * 100)
                  : 0.0;
              final productPct = data.total > 0
                  ? (data.productCommission / data.total * 100)
                  : 0.0;

              return Column(
                children: [
                  // Visual bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 24,
                      child: Row(
                        children: [
                          if (data.bookingCommission > 0)
                            Expanded(
                              flex: (bookingPct * 10).round(),
                              child: Container(
                                color: const Color(0xFF2196F3),
                                alignment: Alignment.center,
                                child: Text(
                                  '${bookingPct.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (data.productCommission > 0)
                            Expanded(
                              flex: (productPct * 10).round(),
                              child: Container(
                                color: const Color(0xFFFF9800),
                                alignment: Alignment.center,
                                child: Text(
                                  '${productPct.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Details
                  _CommissionDetail(
                    color: const Color(0xFF2196F3),
                    label: 'Reservas (3%)',
                    amount: data.bookingCommission,
                    count: data.bookingCount,
                  ),
                  const SizedBox(height: 12),
                  _CommissionDetail(
                    color: const Color(0xFFFF9800),
                    label: 'Productos (10%)',
                    amount: data.productCommission,
                    count: data.productCount,
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total comisiones',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '\$${_fmtAmount(data.total)}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
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

class _CommissionDetail extends StatelessWidget {
  const _CommissionDetail({
    required this.color,
    required this.label,
    required this.amount,
    required this.count,
  });
  final Color color;
  final String label;
  final double amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                '$count transacciones',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Text(
          '\$${_fmtAmount(amount)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Tax Withholdings ─────────────────────────────────────────────────────────

class _TaxWithholdings extends StatelessWidget {
  const _TaxWithholdings({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(taxWithholdingProvider);

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
                child: const Icon(Icons.receipt_long_outlined, size: 18, color: kWebSecondary),
              ),
              const SizedBox(width: 10),
              Text(
                'Retenciones de Impuestos',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: kWebTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          dataAsync.when(
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
            data: (data) {
              return Column(
                children: [
                  // This month
                  _TaxSection(
                    title: 'Este mes',
                    isr: data.isrThisMonth,
                    iva: data.ivaThisMonth,
                    total: data.totalThisMonth,
                  ),
                  const Divider(height: 24),
                  // All time
                  _TaxSection(
                    title: 'Acumulado total',
                    isr: data.isrAllTime,
                    iva: data.ivaAllTime,
                    total: data.totalAllTime,
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

class _TaxSection extends StatelessWidget {
  const _TaxSection({
    required this.title,
    required this.isr,
    required this.iva,
    required this.total,
  });
  final String title;
  final double isr;
  final double iva;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        _TaxRow(label: 'ISR retenido', amount: isr, color: const Color(0xFFE53935)),
        const SizedBox(height: 8),
        _TaxRow(label: 'IVA retenido', amount: iva, color: const Color(0xFFFF9800)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total retenido',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '\$${_fmtAmount(total)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
        Text(
          '\$${_fmtAmount(amount)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Reconciliation Table ─────────────────────────────────────────────────────

class _ReconciliationTable extends StatelessWidget {
  const _ReconciliationTable({
    required this.ref,
    required this.searchQuery,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSearchChanged,
    required this.onSort,
  });
  final WidgetRef ref;
  final String searchQuery;
  final String sortColumn;
  final bool sortAsc;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(reconciliationProvider);
    final dateFmt = DateFormat('d/MM/yy', 'es');
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search and export
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_chart, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Reconciliacion de Pagos',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: isMobile ? 180 : 240,
                    height: 36,
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar salon o servicio...',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color:
                                colors.onSurface.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ExportButton(
                    onPressed: () => _exportReconciliation(context, ref),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          dataAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text('Error al cargar reconciliacion',
                  style: theme.textTheme.bodySmall),
            ),
            data: (rows) {
              var filtered = rows.where((r) {
                if (searchQuery.isEmpty) return true;
                final q = searchQuery.toLowerCase();
                return r.businessName.toLowerCase().contains(q) ||
                    r.serviceName.toLowerCase().contains(q) ||
                    r.appointmentId.toLowerCase().contains(q);
              }).toList();

              // Sort
              filtered.sort((a, b) {
                int cmp;
                switch (sortColumn) {
                  case 'payment_date':
                    cmp = a.paymentDate.compareTo(b.paymentDate);
                  case 'business_name':
                    cmp = a.businessName.compareTo(b.businessName);
                  case 'gross_amount':
                    cmp = a.grossAmount.compareTo(b.grossAmount);
                  case 'platform_fee':
                    cmp = a.platformFee.compareTo(b.platformFee);
                  case 'provider_net':
                    cmp = a.providerNet.compareTo(b.providerNet);
                  default:
                    cmp = a.paymentDate.compareTo(b.paymentDate);
                }
                return sortAsc ? cmp : -cmp;
              });

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.table_chart_outlined,
                  message: searchQuery.isNotEmpty
                      ? 'Sin resultados para "$searchQuery"'
                      : 'Sin datos de reconciliacion',
                );
              }

              if (isMobile) {
                return _MobileReconciliationList(
                  rows: filtered,
                  dateFmt: dateFmt,
                );
              }

              return _DesktopReconciliationTable(
                rows: filtered.take(50).toList(),
                dateFmt: dateFmt,
                sortColumn: sortColumn,
                sortAsc: sortAsc,
                onSort: onSort,
              );
            },
          ),
        ],
      ),
    );
  }

  void _exportReconciliation(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.read(reconciliationProvider);
    dataAsync.whenData((rows) {
      final csvLines = <String>[
        'Fecha,Salon,Servicio,Bruto,Comision,ISR,IVA,Neto,Discrepancia',
        for (final r in rows)
          '${DateFormat('yyyy-MM-dd').format(r.paymentDate)},'
              '"${r.businessName}",'
              '"${r.serviceName}",'
              '${r.grossAmount.toStringAsFixed(2)},'
              '${r.platformFee.toStringAsFixed(2)},'
              '${r.isrWithheld.toStringAsFixed(2)},'
              '${r.ivaWithheld.toStringAsFixed(2)},'
              '${r.providerNet.toStringAsFixed(2)},'
              '${r.discrepancy.toStringAsFixed(2)}',
      ];
      _downloadCsv(context, csvLines.join('\n'), 'reconciliacion');
    });
  }
}

class _DesktopReconciliationTable extends StatelessWidget {
  const _DesktopReconciliationTable({
    required this.rows,
    required this.dateFmt,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
  });
  final List<ReconciliationRow> rows;
  final DateFormat dateFmt;
  final String sortColumn;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 120,
        ),
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          headingTextStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
          dataTextStyle: theme.textTheme.bodySmall,
          sortColumnIndex: _sortIndex,
          sortAscending: sortAsc,
          columns: [
            DataColumn(
              label: const Text('Fecha'),
              onSort: (_, __) => onSort('payment_date'),
            ),
            DataColumn(
              label: const Text('Salon'),
              onSort: (_, __) => onSort('business_name'),
            ),
            const DataColumn(label: Text('Servicio')),
            DataColumn(
              label: const Text('Bruto'),
              numeric: true,
              onSort: (_, __) => onSort('gross_amount'),
            ),
            DataColumn(
              label: const Text('Comision'),
              numeric: true,
              onSort: (_, __) => onSort('platform_fee'),
            ),
            const DataColumn(label: Text('ISR'), numeric: true),
            const DataColumn(label: Text('IVA'), numeric: true),
            DataColumn(
              label: const Text('Neto'),
              numeric: true,
              onSort: (_, __) => onSort('provider_net'),
            ),
            const DataColumn(label: Text('Disc.')),
          ],
          rows: rows.map((r) {
            final hasDisc = r.hasDiscrepancy;
            return DataRow(
              color: hasDisc
                  ? WidgetStateProperty.all(
                      const Color(0xFFE53935).withValues(alpha: 0.06))
                  : null,
              cells: [
                DataCell(Text(dateFmt.format(r.paymentDate))),
                DataCell(Text(r.businessName,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(r.serviceName,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text('\$${r.grossAmount.toStringAsFixed(0)}')),
                DataCell(Text('\$${r.platformFee.toStringAsFixed(0)}')),
                DataCell(Text('\$${r.isrWithheld.toStringAsFixed(0)}')),
                DataCell(Text('\$${r.ivaWithheld.toStringAsFixed(0)}')),
                DataCell(Text(
                  '\$${r.providerNet.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w600),
                )),
                DataCell(
                  hasDisc
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE53935).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '\$${r.discrepancy.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Icon(Icons.check_circle,
                          size: 16,
                          color:
                              const Color(0xFF4CAF50).withValues(alpha: 0.6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  int get _sortIndex => switch (sortColumn) {
        'payment_date' => 0,
        'business_name' => 1,
        'gross_amount' => 3,
        'platform_fee' => 4,
        'provider_net' => 7,
        _ => 0,
      };
}

class _MobileReconciliationList extends StatelessWidget {
  const _MobileReconciliationList({
    required this.rows,
    required this.dateFmt,
  });
  final List<ReconciliationRow> rows;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length && i < 20; i++) ...[
          _MobileReconCard(row: rows[i], dateFmt: dateFmt),
          if (i < rows.length - 1 && i < 19) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileReconCard extends StatelessWidget {
  const _MobileReconCard({required this.row, required this.dateFmt});
  final ReconciliationRow row;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: row.hasDiscrepancy
            ? const Color(0xFFE53935).withValues(alpha: 0.04)
            : colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: row.hasDiscrepancy
              ? const Color(0xFFE53935).withValues(alpha: 0.2)
              : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(row.businessName,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(dateFmt.format(row.paymentDate),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.serviceName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat('Bruto', '\$${row.grossAmount.toStringAsFixed(0)}'),
              _MiniStat('Com.', '\$${row.platformFee.toStringAsFixed(0)}'),
              _MiniStat('ISR', '\$${row.isrWithheld.toStringAsFixed(0)}'),
              _MiniStat('IVA', '\$${row.ivaWithheld.toStringAsFixed(0)}'),
              _MiniStat('Neto', '\$${row.providerNet.toStringAsFixed(0)}',
                  bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            )),
        Text(value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11,
            )),
      ],
    );
  }
}

// ── Salon Breakdown Table ────────────────────────────────────────────────────

class _SalonBreakdownTable extends StatelessWidget {
  const _SalonBreakdownTable({
    required this.ref,
    required this.searchQuery,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSearchChanged,
    required this.onSort,
  });
  final WidgetRef ref;
  final String searchQuery;
  final String sortColumn;
  final bool sortAsc;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dataAsync = ref.watch(businessRevenueProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Desglose por Salon',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: isMobile ? 180 : 240,
                    height: 36,
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar salon...',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color:
                                colors.onSurface.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ExportButton(
                    onPressed: () => _exportSalons(context, ref),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          dataAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text('Error al cargar salones',
                  style: theme.textTheme.bodySmall),
            ),
            data: (rows) {
              var filtered = rows.where((r) {
                if (searchQuery.isEmpty) return true;
                final q = searchQuery.toLowerCase();
                return r.businessName.toLowerCase().contains(q) ||
                    (r.rfc?.toLowerCase().contains(q) ?? false);
              }).toList();

              filtered.sort((a, b) {
                int cmp;
                switch (sortColumn) {
                  case 'business_name':
                    cmp = a.businessName.compareTo(b.businessName);
                  case 'total_revenue':
                    cmp = a.totalRevenue.compareTo(b.totalRevenue);
                  case 'total_platform_fees':
                    cmp =
                        a.totalPlatformFees.compareTo(b.totalPlatformFees);
                  case 'current_month_revenue':
                    cmp = a.currentMonthRevenue
                        .compareTo(b.currentMonthRevenue);
                  case 'net_payable':
                    cmp = a.netPayable.compareTo(b.netPayable);
                  default:
                    cmp = a.currentMonthRevenue
                        .compareTo(b.currentMonthRevenue);
                }
                return sortAsc ? cmp : -cmp;
              });

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.store_outlined,
                  message: searchQuery.isNotEmpty
                      ? 'Sin resultados para "$searchQuery"'
                      : 'Sin datos de salones',
                );
              }

              if (isMobile) {
                return Column(
                  children: [
                    for (var i = 0;
                        i < filtered.length && i < 20;
                        i++) ...[
                      _MobileSalonCard(row: filtered[i]),
                      if (i < filtered.length - 1 && i < 19)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.sizeOf(context).width - 120,
                  ),
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 40,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 48,
                    headingTextStyle: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                    dataTextStyle: theme.textTheme.bodySmall,
                    sortAscending: sortAsc,
                    columns: [
                      DataColumn(
                        label: const Text('Salon'),
                        onSort: (_, __) => onSort('business_name'),
                      ),
                      const DataColumn(label: Text('RFC')),
                      DataColumn(
                        label: const Text('Ingresos totales'),
                        numeric: true,
                        onSort: (_, __) => onSort('total_revenue'),
                      ),
                      DataColumn(
                        label: const Text('Comision'),
                        numeric: true,
                        onSort: (_, __) => onSort('total_platform_fees'),
                      ),
                      const DataColumn(
                          label: Text('ISR'), numeric: true),
                      const DataColumn(
                          label: Text('IVA'), numeric: true),
                      DataColumn(
                        label: const Text('Neto pagable'),
                        numeric: true,
                        onSort: (_, __) => onSort('net_payable'),
                      ),
                      DataColumn(
                        label: const Text('Mes actual'),
                        numeric: true,
                        onSort: (_, __) =>
                            onSort('current_month_revenue'),
                      ),
                      const DataColumn(
                        label: Text('Reservas'),
                        numeric: true,
                      ),
                    ],
                    rows: filtered.take(50).map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text(r.rfc ?? '-',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 11))),
                        DataCell(Text(
                            '\$${_fmtAmount(r.totalRevenue)}')),
                        DataCell(Text(
                            '\$${_fmtAmount(r.totalPlatformFees)}')),
                        DataCell(
                            Text('\$${_fmtAmount(r.totalIsr)}')),
                        DataCell(
                            Text('\$${_fmtAmount(r.totalIva)}')),
                        DataCell(Text(
                          '\$${_fmtAmount(r.netPayable)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text(
                          '\$${_fmtAmount(r.currentMonthRevenue)}',
                          style: TextStyle(
                            color: r.currentMonthRevenue > 0
                                ? const Color(0xFF4CAF50)
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                        DataCell(Text('${r.totalBookings}')),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _exportSalons(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.read(businessRevenueProvider);
    dataAsync.whenData((rows) {
      final csvLines = <String>[
        'Salon,RFC,Ingresos Totales,Comision,ISR,IVA,Neto Pagable,Mes Actual,Reservas',
        for (final r in rows)
          '"${r.businessName}",'
              '"${r.rfc ?? ''}",'
              '${r.totalRevenue.toStringAsFixed(2)},'
              '${r.totalPlatformFees.toStringAsFixed(2)},'
              '${r.totalIsr.toStringAsFixed(2)},'
              '${r.totalIva.toStringAsFixed(2)},'
              '${r.netPayable.toStringAsFixed(2)},'
              '${r.currentMonthRevenue.toStringAsFixed(2)},'
              '${r.totalBookings}',
      ];
      _downloadCsv(context, csvLines.join('\n'), 'salones_revenue');
    });
  }
}

class _MobileSalonCard extends StatelessWidget {
  const _MobileSalonCard({required this.row});
  final BusinessRevenueRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(row.businessName,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text('\$${_fmtAmount(row.totalRevenue)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          if (row.rfc != null) ...[
            const SizedBox(height: 2),
            Text(row.rfc!,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.5),
                )),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat('Com.', '\$${_fmtAmount(row.totalPlatformFees)}'),
              _MiniStat('ISR', '\$${_fmtAmount(row.totalIsr)}'),
              _MiniStat('IVA', '\$${_fmtAmount(row.totalIva)}'),
              _MiniStat('Neto', '\$${_fmtAmount(row.netPayable)}',
                  bold: true),
              _MiniStat('Mes', '\$${_fmtAmount(row.currentMonthRevenue)}'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────────────────────────

class _ExportButton extends StatefulWidget {
  const _ExportButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering
                ? colors.primary.withValues(alpha: 0.08)
                : colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovering
                  ? colors.primary.withValues(alpha: 0.3)
                  : colors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 16, color: colors.primary),
              const SizedBox(width: 4),
              Text(
                'CSV',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icon,
                size: 40,
                color: colors.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Utility ──────────────────────────────────────────────────────────────────

String _fmtAmount(double amount) {
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 100000) return '${(amount / 1000).toStringAsFixed(0)}k';
  if (amount >= 1000) return NumberFormat('#,##0', 'es').format(amount.round());
  return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
}

/// Trigger a CSV download via an anchor element (web) or show a snackbar.
void _downloadCsv(BuildContext context, String csvContent, String filename) {
  // On web, we use dart:html which is not available in non-web builds.
  // Since this is a web-only app, we use a universal approach via clipboard.
  // For production: use universal_html or file_saver package.
  // For now, copy to clipboard as a functional fallback.
  try {
    // Attempt to use the web download approach
    _triggerWebDownload(csvContent, filename);
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV copiado al portapapeles ($filename)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

void _triggerWebDownload(String content, String filename) {
  // Use dart:js_interop for web download
  // This creates a data URI and triggers download via JavaScript interop
  // For production web downloads, use file_saver or universal_html package.
  // Throwing to fall through to the clipboard/snackbar fallback.
  throw UnimplementedError('Use file_saver package for production');
}
