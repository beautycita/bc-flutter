import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/admin_finance_dashboard_provider.dart';

class AdminFinanceDashboardScreen extends ConsumerStatefulWidget {
  const AdminFinanceDashboardScreen({super.key});

  @override
  ConsumerState<AdminFinanceDashboardScreen> createState() =>
      _AdminFinanceDashboardScreenState();
}

class _AdminFinanceDashboardScreenState
    extends ConsumerState<AdminFinanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static final _mxn =
      NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);
  static final _mxnDecimal =
      NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMD, AppConstants.paddingMD, AppConstants.paddingMD, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // Tab bar
        Container(
          color: colors.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
            indicatorColor: colors.primary,
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Resumen'),
              Tab(text: 'Comisiones'),
              Tab(text: 'Pagos'),
              Tab(text: 'CFDI'),
              Tab(text: 'SAT Plataforma'),
              Tab(text: 'SAT Negocios'),
              Tab(text: 'Deudas'),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ResumenTab(mxn: _mxn, mxnDecimal: _mxnDecimal),
              _ComisionesTab(mxnDecimal: _mxnDecimal),
              _PagosTab(mxnDecimal: _mxnDecimal),
              _CfdiTab(mxnDecimal: _mxnDecimal),
              _SatPlataformaTab(mxnDecimal: _mxnDecimal),
              _SatNegociosTab(mxnDecimal: _mxnDecimal),
              _DeudasTab(mxnDecimal: _mxnDecimal),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 1: Resumen (existing content)
// ═══════════════════════════════════════════════════════════════════════════

class _ResumenTab extends ConsumerWidget {
  final NumberFormat mxn;
  final NumberFormat mxnDecimal;

  const _ResumenTab({required this.mxn, required this.mxnDecimal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(financeDashboardKpisProvider);
    final commissionAsync = ref.watch(commissionBreakdownProvider);
    final taxAsync = ref.watch(taxWithholdingProvider);
    final reconciliationAsync = ref.watch(reconciliationProvider);
    final businessRevenueAsync = ref.watch(businessRevenueProvider);
    final debtAsync = ref.watch(salonDebtSummaryProvider);
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(financeDashboardKpisProvider);
        ref.invalidate(commissionBreakdownProvider);
        ref.invalidate(taxWithholdingProvider);
        ref.invalidate(reconciliationProvider);
        ref.invalidate(businessRevenueProvider);
        ref.invalidate(salonDebtSummaryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Revenue KPIs 2x2
          kpisAsync.when(
            data: (kpis) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppConstants.paddingSM,
              crossAxisSpacing: AppConstants.paddingSM,
              childAspectRatio: 1.5,
              children: [
                _KpiCard(label: 'Hoy', value: mxn.format(kpis.revenueToday), icon: Icons.today, color: colors.primary),
                _KpiCard(label: 'Esta Semana', value: mxn.format(kpis.revenueThisWeek), icon: Icons.date_range, color: const Color(0xFF06B6D4)),
                _KpiCard(label: 'Este Mes', value: mxn.format(kpis.revenueThisMonth), icon: Icons.calendar_month, color: const Color(0xFF8B5CF6)),
                _KpiCard(label: 'Total', value: mxn.format(kpis.revenueAllTime), icon: Icons.account_balance, color: const Color(0xFF059669)),
              ],
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error cargando KPIs: $e'),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Quick stats row
          kpisAsync.when(
            data: (kpis) => Row(
              children: [
                Expanded(child: _MiniStat(label: 'Citas hoy', value: '${kpis.bookingsToday}', icon: Icons.event_available)),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(child: _MiniStat(label: 'Usuarios', value: '${kpis.totalUsers}', icon: Icons.people)),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(child: _MiniStat(label: 'Negocios', value: '${kpis.totalBusinesses}', icon: Icons.store)),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Error al cargar', style: TextStyle(color: Colors.red.shade400, fontSize: 13))),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Outstanding debts KPI
          debtAsync.when(
            data: (debt) => debt.totalOutstanding > 0
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
                    child: _KpiCard(
                      label: 'Deudas Pendientes',
                      value: mxnDecimal.format(debt.totalOutstanding),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Error al cargar', style: TextStyle(color: Colors.red.shade400, fontSize: 13))),
            ),
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // Commission breakdown
          _SectionHeader(title: 'Comisiones del Mes'),
          const SizedBox(height: AppConstants.paddingSM),
          commissionAsync.when(
            data: (c) => _WhiteCard(
              child: Column(
                children: [
                  _CommissionRow(label: 'Reservas (3%)', amount: c.bookingCommission, count: c.bookingCount, color: Theme.of(context).colorScheme.primary),
                  const Divider(height: 20),
                  _CommissionRow(label: 'Productos (7%+3%)', amount: c.productCommission, count: c.productCount, color: const Color(0xFFF59E0B)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Comisiones', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                      Text(mxnDecimal.format(c.total), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Tax withholdings
          _SectionHeader(title: 'Retenciones Fiscales'),
          const SizedBox(height: AppConstants.paddingSM),
          taxAsync.when(
            data: (tax) => _WhiteCard(
              child: Column(
                children: [
                  _TaxRow(label: 'ISR este mes', amount: tax.isrThisMonth),
                  const SizedBox(height: 8),
                  _TaxRow(label: 'IVA este mes', amount: tax.ivaThisMonth),
                  const Divider(height: 20),
                  _TaxRow(label: 'Total mes', amount: tax.totalThisMonth, bold: true),
                  const SizedBox(height: 12),
                  _TaxRow(label: 'ISR acumulado', amount: tax.isrAllTime),
                  const SizedBox(height: 8),
                  _TaxRow(label: 'IVA acumulado', amount: tax.ivaAllTime),
                  const Divider(height: 20),
                  _TaxRow(label: 'Total acumulado', amount: tax.totalAllTime, bold: true),
                ],
              ),
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Reconciliation
          _SectionHeader(title: 'Reconciliacion'),
          const SizedBox(height: AppConstants.paddingSM),
          reconciliationAsync.when(
            data: (rows) {
              if (rows.isEmpty) return _EmptyCard(message: 'Sin transacciones recientes');
              return Column(children: rows.take(20).map((r) => _ReconciliationTile(row: r)).toList());
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Error: $e'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Per-salon revenue
          _SectionHeader(title: 'Ingresos por Salon'),
          const SizedBox(height: AppConstants.paddingSM),
          businessRevenueAsync.when(
            data: (rows) {
              if (rows.isEmpty) return _EmptyCard(message: 'Sin datos de salones');
              return Column(children: rows.map((r) => _BusinessRevenueTile(row: r)).toList());
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

// ═══════════════════════════════════════════════════════════════════════════
// Tab 2: Comisiones (commission_records)
// ═══════════════════════════════════════════════════════════════════════════

class _ComisionesTab extends ConsumerWidget {
  final NumberFormat mxnDecimal;
  const _ComisionesTab({required this.mxnDecimal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(commissionRecordsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(commissionRecordsProvider),
      child: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyCard(message: 'Sin registros de comisiones'),
            ]);
          }

          // Group by period (month)
          final byMonth = <String, List<CommissionRecord>>{};
          double totalAppointment = 0;
          double totalProduct = 0;
          for (final r in records) {
            byMonth.putIfAbsent(r.period, () => []).add(r);
            if (r.source == 'appointment') {
              totalAppointment += r.amount;
            } else {
              totalProduct += r.amount;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Citas',
                      value: mxnDecimal.format(totalAppointment),
                      icon: Icons.event,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSM),
                  Expanded(
                    child: _KpiCard(
                      label: 'Productos',
                      value: mxnDecimal.format(totalProduct),
                      icon: Icons.shopping_bag,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingLG),

              // Monthly breakdown
              ...byMonth.entries.map((entry) {
                final period = entry.key;
                final items = entry.value;
                final monthTotal = items.fold(0.0, (sum, r) => sum + r.amount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Periodo: $period'),
                    const SizedBox(height: 4),
                    Text(
                      '${items.length} registros | Total: ${mxnDecimal.format(monthTotal)}',
                      style: GoogleFonts.nunito(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    ...items.take(10).map((r) => _CommissionRecordTile(record: r, mxn: mxnDecimal)),
                    if (items.length > 10)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '... y ${items.length - 10} mas',
                          style: GoogleFonts.nunito(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: AppConstants.paddingMD),
                  ],
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorCard(message: 'Error: $e')),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 3: Pagos (payout_records)
// ═══════════════════════════════════════════════════════════════════════════

class _PagosTab extends ConsumerWidget {
  final NumberFormat mxnDecimal;
  const _PagosTab({required this.mxnDecimal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(payoutRecordsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(payoutRecordsProvider),
      child: payoutsAsync.when(
        data: (payouts) {
          if (payouts.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyCard(message: 'Sin registros de pagos'),
            ]);
          }

          final completed = payouts.where((p) => p.status == 'completed').toList();
          final pending = payouts.where((p) => p.status == 'pending').toList();
          final totalCompleted = completed.fold(0.0, (sum, p) => sum + p.amount);
          final totalPending = pending.fold(0.0, (sum, p) => sum + p.amount);

          return ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Completados',
                      value: mxnDecimal.format(totalCompleted),
                      icon: Icons.check_circle,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSM),
                  Expanded(
                    child: _KpiCard(
                      label: 'Pendientes',
                      value: mxnDecimal.format(totalPending),
                      icon: Icons.pending,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingLG),

              if (pending.isNotEmpty) ...[
                _SectionHeader(title: 'Pagos Pendientes'),
                const SizedBox(height: AppConstants.paddingSM),
                ...pending.map((p) => _PayoutTile(payout: p, mxn: mxnDecimal)),
                const SizedBox(height: AppConstants.paddingLG),
              ],

              _SectionHeader(title: 'Pagos Completados'),
              const SizedBox(height: AppConstants.paddingSM),
              ...completed.take(50).map((p) => _PayoutTile(payout: p, mxn: mxnDecimal)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorCard(message: 'Error: $e')),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 4: CFDI (cfdi_records)
// ═══════════════════════════════════════════════════════════════════════════

class _CfdiTab extends ConsumerWidget {
  final NumberFormat mxnDecimal;
  const _CfdiTab({required this.mxnDecimal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfdiAsync = ref.watch(cfdiRecordsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cfdiRecordsProvider),
      child: cfdiAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyCard(message: 'Sin registros CFDI'),
            ]);
          }

          final timbrado = records.where((r) => r.status == 'timbrado').toList();
          final pendiente = records.where((r) => r.status == 'pendiente').toList();

          return ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Timbrados',
                      value: '${timbrado.length}',
                      icon: Icons.verified,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSM),
                  Expanded(
                    child: _KpiCard(
                      label: 'Pendientes',
                      value: '${pendiente.length}',
                      icon: Icons.hourglass_bottom,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingLG),

              if (pendiente.isNotEmpty) ...[
                _SectionHeader(title: 'CFDI Pendientes'),
                const SizedBox(height: AppConstants.paddingSM),
                ...pendiente.map((r) => _CfdiTile(record: r, mxn: mxnDecimal)),
                const SizedBox(height: AppConstants.paddingLG),
              ],

              _SectionHeader(title: 'CFDI Timbrados'),
              const SizedBox(height: AppConstants.paddingSM),
              ...timbrado.take(50).map((r) => _CfdiTile(record: r, mxn: mxnDecimal)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorCard(message: 'Error: $e')),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 5: SAT Plataforma (platform_sat_declarations)
// ═══════════════════════════════════════════════════════════════════════════

class _SatPlataformaTab extends ConsumerWidget {
  final NumberFormat mxnDecimal;
  const _SatPlataformaTab({required this.mxnDecimal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final declarationsAsync = ref.watch(platformSatDeclarationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(platformSatDeclarationsProvider),
      child: declarationsAsync.when(
        data: (declarations) {
          if (declarations.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyCard(message: 'Sin declaraciones SAT'),
            ]);
          }

          return ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              _SectionHeader(title: 'Declaraciones SAT - Plataforma'),
              const SizedBox(height: AppConstants.paddingSM),
              ...declarations.map((d) => _SatDeclarationTile(declaration: d, mxn: mxnDecimal)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorCard(message: 'Error: $e')),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 6: SAT Negocios (sat_monthly_reports)
// ═══════════════════════════════════════════════════════════════════════════

class _SatNegociosTab extends ConsumerWidget {
  final NumberFormat mxnDecimal;
  const _SatNegociosTab({required this.mxnDecimal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(satMonthlyReportsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(satMonthlyReportsProvider),
      child: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyCard(message: 'Sin reportes SAT de negocios'),
            ]);
          }

          // Group by period
          final byPeriod = <String, List<SatMonthlyReport>>{};
          for (final r in reports) {
            byPeriod.putIfAbsent(r.period, () => []).add(r);
          }

          return ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              ...byPeriod.entries.map((entry) {
                final period = entry.key;
                final items = entry.value;
                final totalRev = items.fold(0.0, (sum, r) => sum + r.revenue);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Periodo: $period'),
                    const SizedBox(height: 4),
                    Text(
                      '${items.length} negocios | Ingresos: ${mxnDecimal.format(totalRev)}',
                      style: GoogleFonts.nunito(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    ...items.map((r) => _SatReportTile(report: r, mxn: mxnDecimal)),
                    const SizedBox(height: AppConstants.paddingMD),
                  ],
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorCard(message: 'Error: $e')),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 7: Deudas (salon_debts + debt_payments)
// ═══════════════════════════════════════════════════════════════════════════

class _DeudasTab extends ConsumerWidget {
  final NumberFormat mxnDecimal;
  const _DeudasTab({required this.mxnDecimal});

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(salonDebtSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(salonDebtSummaryProvider),
      child: debtAsync.when(
        data: (summary) {
          if (summary.debts.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyCard(message: 'Sin deudas registradas'),
            ]);
          }

          return ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              // Summary KPIs
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Deuda Total',
                      value: mxnDecimal.format(summary.totalOutstanding),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSM),
                  Expanded(
                    child: _KpiCard(
                      label: 'Salones con Deuda',
                      value: '${summary.salonsWithDebt}',
                      icon: Icons.store,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingLG),

              // Debt list
              _SectionHeader(title: 'Deudas por Salon'),
              const SizedBox(height: AppConstants.paddingSM),
              ...summary.debts.map((debt) => _DebtTile(debt: debt, mxn: mxnDecimal, dateFmt: _dateFmt)),

              if (summary.recentPayments.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingLG),
                _SectionHeader(title: 'Pagos Recientes'),
                const SizedBox(height: AppConstants.paddingSM),
                ...summary.recentPayments.map((p) => _DebtPaymentTile(payment: p, mxn: mxnDecimal, dateFmt: _dateFmt)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorCard(message: 'Error: $e')),
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  final SalonDebt debt;
  final NumberFormat mxn;
  final DateFormat dateFmt;
  const _DebtTile({required this.debt, required this.mxn, required this.dateFmt});

  static final _detailFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final isPending = debt.isPending;
    final statusColor = isPending ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final statusLabel = isPending ? 'Pendiente' : 'Saldada';

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(AppConstants.paddingSM),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFFFEF2F2) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          border: isPending ? Border.all(color: const Color(0xFFFCA5A5), width: 0.5) : null,
          boxShadow: [
            BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(debt.businessName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _MiniLabel(label: 'Original', value: mxn.format(debt.originalAmount))),
                Expanded(child: _MiniLabel(label: 'Restante', value: mxn.format(debt.remainingAmount))),
                Expanded(child: _MiniLabel(label: 'Creada', value: dateFmt.format(debt.createdAt.toLocal()))),
                if (debt.clearedAt != null)
                  Expanded(child: _MiniLabel(label: 'Saldada', value: dateFmt.format(debt.clearedAt!.toLocal()))),
              ],
            ),
            if (debt.reason != null && debt.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(debt.reason!,
                  style: GoogleFonts.nunito(fontSize: 11, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Detalle Deuda',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _finDetailRow('ID', debt.id),
            _finDetailRow('Negocio ID', debt.businessId),
            _finDetailRow('Negocio', debt.businessName),
            _finDetailRow('Monto original', mxn.format(debt.originalAmount)),
            _finDetailRow('Monto restante', mxn.format(debt.remainingAmount)),
            _finDetailRow('Razon', debt.reason),
            _finDetailRow('Estado', debt.isPending ? 'Pendiente' : 'Saldada'),
            _finDetailRow('Creada', _detailFmt.format(debt.createdAt.toLocal())),
            _finDetailRow('Saldada', debt.clearedAt != null
                ? _detailFmt.format(debt.clearedAt!.toLocal()) : null),
          ],
        ),
      ),
    );
  }
}

class _DebtPaymentTile extends StatelessWidget {
  final DebtPayment payment;
  final NumberFormat mxn;
  final DateFormat dateFmt;
  const _DebtPaymentTile({required this.payment, required this.mxn, required this.dateFmt});

  static final _detailFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(AppConstants.paddingSM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          boxShadow: [
            BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payment.businessName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(dateFmt.format(payment.createdAt.toLocal()),
                      style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  if (payment.note != null && payment.note!.isNotEmpty)
                    Text(payment.note!,
                        style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          Text(mxn.format(payment.amount),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
        ],
      ),
    ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Detalle Pago de Deuda',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _finDetailRow('ID', payment.id),
            _finDetailRow('Deuda ID', payment.debtId),
            _finDetailRow('Negocio', payment.businessName),
            _finDetailRow('Monto', mxn.format(payment.amount)),
            _finDetailRow('Nota', payment.note),
            _finDetailRow('Creado', _detailFmt.format(payment.createdAt.toLocal())),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// New tile widgets for each tab
// ═══════════════════════════════════════════════════════════════════════════

class _CommissionRecordTile extends StatelessWidget {
  final CommissionRecord record;
  final NumberFormat mxn;
  const _CommissionRecordTile({required this.record, required this.mxn});

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final isAppt = record.source == 'appointment';
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(AppConstants.paddingSM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          boxShadow: [
            BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (isAppt ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isAppt ? Icons.event : Icons.shopping_bag,
                size: 16,
                color: isAppt ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.businessName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${isAppt ? 'Cita' : 'Producto'} | ${_dateFmt.format(record.createdAt)}',
                      style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Text(mxn.format(record.amount),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Detalle Comision',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _finDetailRow('ID', record.id),
            _finDetailRow('Negocio ID', record.businessId),
            _finDetailRow('Negocio', record.businessName),
            _finDetailRow('Fuente', record.source),
            _finDetailRow('Monto', mxn.format(record.amount)),
            _finDetailRow('Referencia ID', record.referenceId),
            _finDetailRow('Periodo', record.period),
            _finDetailRow('Creado', _dateFmt.format(record.createdAt.toLocal())),
          ],
        ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final PayoutRecord payout;
  final NumberFormat mxn;
  const _PayoutTile({required this.payout, required this.mxn});

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final isPending = payout.status == 'pending';
    final statusColor = isPending ? const Color(0xFFF59E0B) : const Color(0xFF059669);
    final statusLabel = isPending ? 'Pendiente' : 'Completado';

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(AppConstants.paddingSM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          border: isPending ? Border.all(color: const Color(0xFFFDE68A), width: 0.5) : null,
          boxShadow: [
            BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payout.businessName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${_dateFmt.format(payout.createdAt)} | ${payout.period}',
                      style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                  if (payout.referenceNumber != null && payout.referenceNumber!.isNotEmpty)
                    Text('Ref: ${payout.referenceNumber}',
                        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(mxn.format(payout.amount),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Detalle Pago',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _finDetailRow('ID', payout.id),
            _finDetailRow('Negocio ID', payout.businessId),
            _finDetailRow('Negocio', payout.businessName),
            _finDetailRow('Monto', mxn.format(payout.amount)),
            _finDetailRow('Metodo', payout.paymentMethod),
            _finDetailRow('Referencia', payout.referenceNumber),
            _finDetailRow('Periodo', payout.period),
            _finDetailRow('Estado', payout.status),
            _finDetailRow('Creado', _dateFmt.format(payout.createdAt.toLocal())),
          ],
        ),
      ),
    );
  }
}

class _CfdiTile extends StatelessWidget {
  final CfdiRecord record;
  final NumberFormat mxn;
  const _CfdiTile({required this.record, required this.mxn});

  @override
  Widget build(BuildContext context) {
    final isTimbrado = record.status == 'timbrado';
    final statusColor = isTimbrado ? const Color(0xFF059669) : const Color(0xFFF59E0B);
    final statusLabel = isTimbrado ? 'Timbrado' : 'Pendiente';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppConstants.paddingSM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: InkWell(
        onTap: () => _showCfdiDetail(context),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isTimbrado ? Icons.verified : Icons.hourglass_bottom,
                size: 16,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.businessName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${record.period}${record.folio != null ? ' | Folio: ${record.folio}' : ''}',
                      style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(mxn.format(record.total),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  void _showCfdiDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) {
          final colors = Theme.of(ctx).colorScheme;
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Detalle CFDI',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface)),
              const SizedBox(height: 16),
              _finDetailRow('ID', record.id),
              _finDetailRow('Negocio ID', record.businessId),
              _finDetailRow('Negocio', record.businessName),
              _finDetailRow('Periodo', record.period),
              _finDetailRow('Estado', record.status),
              _finDetailRow('Folio', record.folio),
              _finDetailRow('UUID Fiscal', record.uuidFiscal),
              if (record.uuidFiscal != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: record.uuidFiscal!));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('UUID copiado'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Text('Copiar UUID',
                      style: GoogleFonts.nunito(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 20),
              _finDetailRow('Subtotal', mxn.format(record.subtotal)),
              _finDetailRow('IVA', mxn.format(record.iva)),
              _finDetailRow('Total', mxn.format(record.total)),
              _finDetailRow('Creado', _dateFmt.format(record.createdAt.toLocal())),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _SatDeclarationTile extends StatelessWidget {
  final PlatformSatDeclaration declaration;
  final NumberFormat mxn;
  const _SatDeclarationTile({required this.declaration, required this.mxn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(declaration.period,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (declaration.status == 'presentada' ? const Color(0xFF059669) : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  declaration.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: declaration.status == 'presentada' ? const Color(0xFF059669) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniLabel(label: 'Ingresos', value: mxn.format(declaration.totalRevenue))),
              Expanded(child: _MiniLabel(label: 'IVA', value: mxn.format(declaration.ivaCollected))),
              Expanded(child: _MiniLabel(label: 'ISR', value: mxn.format(declaration.isrCollected))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _MiniLabel(label: 'Int. bancarios', value: mxn.format(declaration.bankInterest))),
              Expanded(child: _MiniLabel(label: 'Uber refs', value: mxn.format(declaration.uberReferrals))),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _SatReportTile extends StatelessWidget {
  final SatMonthlyReport report;
  final NumberFormat mxn;
  const _SatReportTile({required this.report, required this.mxn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppConstants.paddingSM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.businessName,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _MiniLabel(label: 'Ingreso', value: mxn.format(report.revenue))),
              Expanded(child: _MiniLabel(label: 'IVA', value: mxn.format(report.ivaWithheld))),
              Expanded(child: _MiniLabel(label: 'ISR', value: mxn.format(report.isrWithheld))),
              Expanded(child: _MiniLabel(label: 'Neto', value: mxn.format(report.netPayout))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Free function used in detail sheets across the finance dashboard tiles.
Widget _finDetailRow(String label, String? value) => Builder(
  builder: (context) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 130,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
      Expanded(
        child: Text(
          value ?? '—',
          style: GoogleFonts.nunito(fontSize: 13),
        ),
      ),
    ],
  ),
));

class _MiniLabel extends StatelessWidget {
  final String label;
  final String value;
  const _MiniLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
        Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reusable widgets (shared across tabs)
// ═══════════════════════════════════════════════════════════════════════════

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                child: Text(label,
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
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

  const _MiniStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSM, vertical: AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          Text(label, style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), textAlign: TextAlign.center),
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

  const _CommissionRow({required this.label, required this.amount, required this.count, required this.color});

  static final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              Text('$count operaciones', style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
        Text(_fmt.format(amount), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _TaxRow({required this.label, required this.amount, this.bold = false});

  static final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        Text(_fmt.format(amount),
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
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
        color: hasIssue ? const Color(0xFFFEF2F2) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: hasIssue ? Border.all(color: const Color(0xFFFCA5A5), width: 0.5) : null,
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.businessName,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${row.serviceName} - ${_dateFmt.format(row.paymentDate)}',
                    style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt.format(row.grossAmount),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              Text(row.paymentStatus,
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: row.paymentStatus == 'succeeded' ? const Color(0xFF059669) : const Color(0xFFDC2626))),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.businessName,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${row.totalBookings} citas | Este mes: ${_fmt.format(row.currentMonthRevenue)}',
                    style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt.format(row.totalRevenue),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              Text('Neto: ${_fmt.format(row.netPayable)}',
                  style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF059669))),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
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
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
      child: Text(message, style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFFDC2626))),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
      child: Center(child: Text(message, style: GoogleFonts.nunito(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)))),
    );
  }
}

