import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/admin_finance_dashboard_provider.dart';

class AdminFinanceDashboardScreen extends ConsumerWidget {
  const AdminFinanceDashboardScreen({super.key});

  static final _mxn = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);
  static final _mxnDecimal = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(financeDashboardKpisProvider);
    final commissionAsync = ref.watch(commissionBreakdownProvider);
    final taxAsync = ref.watch(taxWithholdingProvider);
    final reconciliationAsync = ref.watch(reconciliationProvider);
    final businessRevenueAsync = ref.watch(businessRevenueProvider);
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(financeDashboardKpisProvider);
        ref.invalidate(commissionBreakdownProvider);
        ref.invalidate(taxWithholdingProvider);
        ref.invalidate(reconciliationProvider);
        ref.invalidate(businessRevenueProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          Text(
            'Finanzas CEO',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Resumen financiero de la plataforma',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // ── Revenue KPIs 2x2 ──
          kpisAsync.when(
            data: (kpis) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppConstants.paddingSM,
              crossAxisSpacing: AppConstants.paddingSM,
              childAspectRatio: 1.5,
              children: [
                _KpiCard(
                  label: 'Hoy',
                  value: _mxn.format(kpis.revenueToday),
                  icon: Icons.today,
                  color: colors.primary,
                ),
                _KpiCard(
                  label: 'Esta Semana',
                  value: _mxn.format(kpis.revenueThisWeek),
                  icon: Icons.date_range,
                  color: const Color(0xFF06B6D4),
                ),
                _KpiCard(
                  label: 'Este Mes',
                  value: _mxn.format(kpis.revenueThisMonth),
                  icon: Icons.calendar_month,
                  color: const Color(0xFF8B5CF6),
                ),
                _KpiCard(
                  label: 'Total',
                  value: _mxn.format(kpis.revenueAllTime),
                  icon: Icons.account_balance,
                  color: const Color(0xFF059669),
                ),
              ],
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error cargando KPIs: $e'),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Quick stats row ──
          kpisAsync.when(
            data: (kpis) => Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Citas hoy',
                    value: '${kpis.bookingsToday}',
                    icon: Icons.event_available,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: _MiniStat(
                    label: 'Usuarios',
                    value: '${kpis.totalUsers}',
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: _MiniStat(
                    label: 'Negocios',
                    value: '${kpis.totalBusinesses}',
                    icon: Icons.store,
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Commission breakdown ──
          _SectionHeader(title: 'Comisiones del Mes'),
          const SizedBox(height: AppConstants.paddingSM),
          commissionAsync.when(
            data: (c) => Container(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _CommissionRow(
                    label: 'Reservas (3%)',
                    amount: c.bookingCommission,
                    count: c.bookingCount,
                    color: colors.primary,
                  ),
                  const Divider(height: 20),
                  _CommissionRow(
                    label: 'Productos (10%)',
                    amount: c.productCommission,
                    count: c.productCount,
                    color: const Color(0xFFF59E0B),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Comisiones',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF212121),
                        ),
                      ),
                      Text(
                        _mxnDecimal.format(c.total),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Tax withholdings ──
          _SectionHeader(title: 'Retenciones Fiscales'),
          const SizedBox(height: AppConstants.paddingSM),
          taxAsync.when(
            data: (tax) => Container(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _TaxRow(label: 'ISR este mes', amount: tax.isrThisMonth),
                  const SizedBox(height: 8),
                  _TaxRow(label: 'IVA este mes', amount: tax.ivaThisMonth),
                  const Divider(height: 20),
                  _TaxRow(
                    label: 'Total mes',
                    amount: tax.totalThisMonth,
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  _TaxRow(label: 'ISR acumulado', amount: tax.isrAllTime),
                  const SizedBox(height: 8),
                  _TaxRow(label: 'IVA acumulado', amount: tax.ivaAllTime),
                  const Divider(height: 20),
                  _TaxRow(
                    label: 'Total acumulado',
                    amount: tax.totalAllTime,
                    bold: true,
                  ),
                ],
              ),
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Reconciliation ──
          _SectionHeader(title: 'Reconciliacion'),
          const SizedBox(height: AppConstants.paddingSM),
          reconciliationAsync.when(
            data: (rows) {
              if (rows.isEmpty) {
                return _EmptyCard(message: 'Sin transacciones recientes');
              }
              return Column(
                children: rows.take(20).map((r) => _ReconciliationTile(row: r)).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Per-salon revenue ──
          _SectionHeader(title: 'Ingresos por Salon'),
          const SizedBox(height: AppConstants.paddingSM),
          businessRevenueAsync.when(
            data: (rows) {
              if (rows.isEmpty) {
                return _EmptyCard(message: 'Sin datos de salones');
              }
              return Column(
                children: rows.map((r) => _BusinessRevenueTile(row: r)).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingXL),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF212121),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF757575),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM,
        vertical: AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF212121),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CommissionRow extends StatelessWidget {
  final String label;
  final double amount;
  final int count;
  final Color color;

  const _CommissionRow({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });

  static final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF424242),
                ),
              ),
              Text(
                '$count operaciones',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
        Text(
          _fmt.format(amount),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF212121),
          ),
        ),
      ],
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _TaxRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  static final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? const Color(0xFF212121) : const Color(0xFF616161),
          ),
        ),
        Text(
          _fmt.format(amount),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? const Color(0xFF212121) : const Color(0xFF424242),
          ),
        ),
      ],
    );
  }
}

class _ReconciliationTile extends StatelessWidget {
  final ReconciliationRow row;
  const _ReconciliationTile({required this.row});

  static final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);
  static final _dateFmt = DateFormat('dd/MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final hasIssue = row.hasDiscrepancy;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppConstants.paddingSM),
      decoration: BoxDecoration(
        color: hasIssue ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: hasIssue
            ? Border.all(color: const Color(0xFFFCA5A5), width: 0.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.businessName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${row.serviceName} - ${_dateFmt.format(row.paymentDate)}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt.format(row.grossAmount),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              Text(
                row.paymentStatus,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: row.paymentStatus == 'succeeded'
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessRevenueTile extends StatelessWidget {
  final BusinessRevenueRow row;
  const _BusinessRevenueTile({required this.row});

  static final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppConstants.paddingSM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.businessName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${row.totalBookings} citas | Este mes: ${_fmt.format(row.currentMonthRevenue)}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt.format(row.totalRevenue),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              Text(
                'Neto: ${_fmt.format(row.netPayable)}',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
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
        color: Colors.white,
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
        color: Colors.white,
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
