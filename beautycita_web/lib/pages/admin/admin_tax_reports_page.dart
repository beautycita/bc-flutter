import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/web_theme.dart';
import '../../providers/admin_tax_reports_provider.dart';
import '../../services/csv_export.dart';

/// Admin Tax Reports page — period selector, generate button, summary KPIs,
/// per-business breakdown table, and CSV export.
///
/// Desktop-first. Calls the `sat-reporting` edge function to generate the report.
class AdminTaxReportsPage extends ConsumerWidget {
  const AdminTaxReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(taxReportPeriodProvider);
    final reportState = ref.watch(adminTaxReportProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(period: period, ref: ref, reportState: reportState),
          const SizedBox(height: 24),
          if (reportState == null) ...[
            _EmptyState(),
          ] else if (reportState.isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (reportState.hasError) ...[
            _ErrorCard(error: '${reportState.error}'),
          ] else ...[
            _SummaryCards(summary: reportState.value!.summary),
            const SizedBox(height: 24),
            _BusinessBreakdownTable(
              businesses: reportState.value!.businesses,
              ref: ref,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Page header with period selector + generate button ────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.period,
    required this.ref,
    required this.reportState,
  });

  final TaxReportPeriod period;
  final WidgetRef ref;
  final AsyncValue<TaxReport>? reportState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = reportState?.isLoading ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reportes Fiscales',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kWebTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Retenciones ISR/IVA por periodo · Función SAT Reporting',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Year dropdown
        _PeriodDropdown<int>(
          value: period.year,
          items: {
            for (var y = DateTime.now().year; y >= 2024; y--)
              y: '$y',
          },
          onChanged: (y) {
            if (y != null) {
              ref.read(taxReportPeriodProvider.notifier).state =
                  period.copyWith(year: y);
            }
          },
          tooltip: 'Año',
        ),
        const SizedBox(width: 8),

        // Month dropdown
        _PeriodDropdown<int>(
          value: period.month,
          items: {
            for (var m = 1; m <= 12; m++)
              m: DateFormat('MMMM', 'es').format(DateTime(2000, m)),
          },
          onChanged: (m) {
            if (m != null) {
              ref.read(taxReportPeriodProvider.notifier).state =
                  period.copyWith(month: m);
            }
          },
          tooltip: 'Mes',
        ),
        const SizedBox(width: 12),

        // Generate button
        FilledButton.icon(
          onPressed: isLoading
              ? null
              : () => AdminTaxReportNotifier.generate(ref, period),
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(isLoading ? 'Generando...' : 'Generar reporte'),
          style: FilledButton.styleFrom(
            backgroundColor: kWebPrimary,
          ),
        ),
      ],
    );
  }
}

class _PeriodDropdown<T> extends StatelessWidget {
  const _PeriodDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.tooltip,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: kWebCardBorder),
          borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
          color: kWebSurface,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextPrimary,
            ),
            items: items.entries
                .map((e) => DropdownMenuItem<T>(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: kWebTextHint.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Selecciona un periodo y genera el reporte',
              style: theme.textTheme.titleMedium?.copyWith(
                color: kWebTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los datos se obtienen en tiempo real de la función SAT Reporting',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kWebTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error al generar reporte',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error.withValues(alpha: 0.8),
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

// ── Summary KPI cards ─────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final TaxReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );

    final cards = [
      (
        icon: Icons.receipt_outlined,
        label: 'Transacciones',
        value: '${summary.totalTransactions}',
        color: kWebTertiary,
      ),
      (
        icon: Icons.account_balance_outlined,
        label: 'ISR Retenido',
        value: currency.format(summary.isrWithheld),
        color: kWebSecondary,
      ),
      (
        icon: Icons.percent_outlined,
        label: 'IVA Retenido',
        value: currency.format(summary.ivaWithheld),
        color: kWebPrimary,
      ),
      (
        icon: Icons.payments_outlined,
        label: 'Comisiones',
        value: currency.format(summary.platformFees),
        color: Colors.orange,
      ),
      (
        icon: Icons.trending_up_outlined,
        label: 'Ingreso Bruto',
        value: currency.format(summary.grossRevenue),
        color: Colors.green,
      ),
      (
        icon: Icons.send_outlined,
        label: 'Pago Neto',
        value: currency.format(summary.netPayout),
        color: Colors.teal,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map((c) => SizedBox(
                width: 180,
                child: _KpiTile(
                  icon: c.icon,
                  label: c.label,
                  value: c.value,
                  color: c.color,
                ),
              ))
          .toList(),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: kWebTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-business breakdown table ──────────────────────────────────────────────

class _BusinessBreakdownTable extends ConsumerWidget {
  const _BusinessBreakdownTable({
    required this.businesses,
    required this.ref,
  });

  final List<TaxReportBusiness> businesses;
  final WidgetRef ref;

  List<TaxReportBusiness> _sorted(
      List<TaxReportBusiness> rows, TaxTableSort sort) {
    final list = List<TaxReportBusiness>.from(rows);
    list.sort((a, b) {
      int cmp;
      switch (sort.column) {
        case 'name':
          cmp = a.businessName.compareTo(b.businessName);
        case 'transactions':
          cmp = a.transactions.compareTo(b.transactions);
        case 'gross_revenue':
          cmp = a.grossRevenue.compareTo(b.grossRevenue);
        case 'isr':
          cmp = a.isrWithheld.compareTo(b.isrWithheld);
        case 'iva':
          cmp = a.ivaWithheld.compareTo(b.ivaWithheld);
        case 'platform_fee':
          cmp = a.platformFee.compareTo(b.platformFee);
        case 'net_payout':
          cmp = a.netPayout.compareTo(b.netPayout);
        default:
          cmp = a.grossRevenue.compareTo(b.grossRevenue);
      }
      return sort.ascending ? cmp : -cmp;
    });
    return list;
  }

  void _exportCsv(BuildContext context, List<TaxReportBusiness> rows) {
    final csv = generateCsv(
      headers: [
        'Negocio',
        'Transacciones',
        'Ingreso Bruto',
        'ISR Retenido',
        'IVA Retenido',
        'Comisión',
        'Pago Neto',
      ],
      rows: rows
          .map((b) => [
                b.businessName,
                '${b.transactions}',
                b.grossRevenue.toStringAsFixed(2),
                b.isrWithheld.toStringAsFixed(2),
                b.ivaWithheld.toStringAsFixed(2),
                b.platformFee.toStringAsFixed(2),
                b.netPayout.toStringAsFixed(2),
              ])
          .toList(),
    );
    downloadCsv(csv,
        'reporte_fiscal_${DateTime.now().millisecondsSinceEpoch}.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV descargado')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sort = ref.watch(taxTableSortProvider);
    final rows = _sorted(businesses, sort);
    final currency = NumberFormat.currency(
        locale: 'es_MX', symbol: r'$', decimalDigits: 2);

    void toggleSort(String column) {
      final notifier = ref.read(taxTableSortProvider.notifier);
      if (sort.column == column) {
        notifier.state = sort.copyWith(ascending: !sort.ascending);
      } else {
        notifier.state = sort.copyWith(column: column, ascending: false);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Desglose por negocio (${businesses.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: kWebTextPrimary,
                  ),
                ),
                const Spacer(),
                if (businesses.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _exportCsv(context, rows),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Exportar CSV'),
                    style: TextButton.styleFrom(
                      foregroundColor: kWebTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (businesses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Sin datos para el periodo seleccionado',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kWebTextHint,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: null,
                headingRowColor: WidgetStateProperty.all(
                    kWebBackground.withValues(alpha: 0.5)),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columnSpacing: 20,
                horizontalMargin: 20,
                columns: [
                  _sortableColumn('Negocio', 'name', sort, toggleSort),
                  _sortableColumn('Transacciones', 'transactions', sort, toggleSort),
                  _sortableColumn('Bruto', 'gross_revenue', sort, toggleSort),
                  _sortableColumn('ISR', 'isr', sort, toggleSort),
                  _sortableColumn('IVA', 'iva', sort, toggleSort),
                  _sortableColumn('Comisión', 'platform_fee', sort, toggleSort),
                  _sortableColumn('Neto', 'net_payout', sort, toggleSort),
                ],
                rows: rows.map((b) {
                  return DataRow(cells: [
                    DataCell(Text(
                      b.businessName,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500),
                    )),
                    DataCell(Text('${b.transactions}',
                        style: theme.textTheme.bodySmall)),
                    DataCell(Text(currency.format(b.grossRevenue),
                        style: theme.textTheme.bodySmall)),
                    DataCell(Text(
                      currency.format(b.isrWithheld),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kWebSecondary,
                      ),
                    )),
                    DataCell(Text(
                      currency.format(b.ivaWithheld),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kWebPrimary,
                      ),
                    )),
                    DataCell(Text(currency.format(b.platformFee),
                        style: theme.textTheme.bodySmall)),
                    DataCell(Text(
                      currency.format(b.netPayout),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  DataColumn _sortableColumn(
    String label,
    String column,
    TaxTableSort sort,
    void Function(String) onSort,
  ) {
    final isActive = sort.column == column;
    return DataColumn(
      label: InkWell(
        onTap: () => onSort(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? kWebPrimary : kWebTextSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? (sort.ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isActive ? kWebPrimary : kWebTextHint,
            ),
          ],
        ),
      ),
    );
  }
}
