import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../config/theme_extension.dart';
import '../../providers/business_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import 'package:beautycita/widgets/admin/admin_widgets.dart';
import '../../providers/banking_setup_provider.dart';
import 'banking_setup_screen.dart';

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
          // Banking setup banner
          _BankingBanner(),

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

          // Top Staff this month
          const _TopStaffSection(),

          const SizedBox(height: AppConstants.paddingMD),

          // Outstanding Debt Warning
          _DebtCard(),

          const SizedBox(height: AppConstants.paddingMD),

          // Tax & Deductions Card
          _TaxDeductionsCard(),

          const SizedBox(height: AppConstants.paddingLG),

          // CFDI Records section
          _CfdiSection(),

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
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              child: Text('No se pudieron cargar las citas',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
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
    final bcExt = Theme.of(context).extension<BCThemeExtension>()!;

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
          color: bcExt.successColor,
        ),
        _StatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Por Confirmar',
          value: '${stats.pendingConfirmations}',
          color: bcExt.warningColor,
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

class _TopStaffSection extends ConsumerWidget {
  const _TopStaffSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(staffProductivityProvider('month'));
    final fmt = NumberFormat('#,##0', 'es_MX');

    return dataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.entries.isEmpty) return const SizedBox.shrink();

        final sorted = [...data.entries]
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
        final top3 = sorted.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 20, color: const Color(0xFFFFB300)),
                const SizedBox(width: 6),
                Text('Top Staff del Mes',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    )),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < top3.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1,
                          color: colors.onSurface.withValues(alpha: 0.06)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          // Rank medal
                          SizedBox(
                            width: 24,
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: 16,
                              color: i == 0
                                  ? const Color(0xFFFFB300)
                                  : i == 1
                                      ? const Color(0xFF90A4AE)
                                      : const Color(0xFFBF8040),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Name
                          Expanded(
                            child: Text(top3[i].firstName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          // Appointments count
                          Text('${top3[i].completedAppointments} citas',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              )),
                          const SizedBox(width: 12),
                          // Revenue
                          Text('\$${fmt.format(top3[i].revenue)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).extension<BCThemeExtension>()!.successColor,
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
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

    final statusColor = _statusColor(status, context);

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

  Color _statusColor(String status, BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    switch (status) {
      case 'pending':
        return ext.warningColor;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return ext.successColor;
      case 'cancelled_customer':
      case 'cancelled_business':
        return Theme.of(context).colorScheme.error;
      case 'no_show':
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
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

// ═══════════════════════════════════════════════════════════════════════════
// Tax & Deductions Dashboard Card
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// Outstanding Debt Card — red warning when salon owes BC
// ═══════════════════════════════════════════════════════════════════════════

class _DebtCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      data: (biz) {
        if (biz == null) return const SizedBox.shrink();
        final debt = (biz['outstanding_debt'] as num?)?.toDouble() ?? 0;
        if (debt <= 0) return const SizedBox.shrink();

        final errorColor = Theme.of(context).colorScheme.error;
        return Card(
          elevation: 0,
          color: errorColor.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: errorColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: errorColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo pendiente',
                        style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700, color: errorColor)),
                      const SizedBox(height: 2),
                      Text('\$${NumberFormat('#,##0.00', 'es_MX').format(debt)} MXN',
                        style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w800, color: errorColor)),
                      const SizedBox(height: 4),
                      Text(
                        'Se descontara hasta 50% de cada servicio hasta saldar. '
                        'Contacta soporte para detalles.',
                        style: GoogleFonts.nunito(
                          fontSize: 11, color: errorColor, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppConstants.paddingMD),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Center(child: Text('Error al cargar', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))),
      ),
    );
  }
}

class _TaxDeductionsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TaxDeductionsCard> createState() => _TaxDeductionsCardState();
}

class _TaxDeductionsCardState extends ConsumerState<_TaxDeductionsCard> {
  double _revenueYtd = 0;
  double _ivaWithheld = 0;
  double _isrWithheld = 0;
  double _expensesYtd = 0;
  double _commissionServices = 0;
  double _commissionProducts = 0;
  bool _loading = true;
  final List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _expenseRows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) return;
      final bizId = biz['id'] as String;
      final year = DateTime.now().year;

      // Revenue + actual tax withholdings YTD from paid appointments
      final revenueRows = await SupabaseClientService.client
          .from(BCTables.appointments)
          .select('price, starts_at, isr_withheld, iva_withheld')
          .eq('business_id', bizId)
          .inFilter('status', ['completed', 'confirmed'])
          .eq('payment_status', 'paid')
          .gte('starts_at', '$year-01-01');

      double rev = 0;
      double actualIsr = 0;
      double actualIva = 0;
      for (final r in revenueRows) {
        rev += (r['price'] as num?)?.toDouble() ?? 0;
        actualIsr += (r['isr_withheld'] as num?)?.toDouble() ?? 0;
        actualIva += (r['iva_withheld'] as num?)?.toDouble() ?? 0;
      }

      // Expenses YTD
      final expRows = await SupabaseClientService.client
          .from(BCTables.businessExpenses)
          .select('id, amount, month, description, created_at')
          .eq('business_id', bizId)
          .eq('year', year)
          .order('created_at', ascending: false);

      double exp = 0;
      for (final r in expRows) {
        exp += (r['amount'] as num?)?.toDouble() ?? 0;
      }

      // Commission records YTD
      final commRows = await SupabaseClientService.client
          .from(BCTables.commissionRecords)
          .select('amount, source')
          .eq('business_id', bizId)
          .gte('created_at', '$year-01-01T00:00:00Z');

      double commSvc = 0;
      double commProd = 0;
      for (final r in commRows) {
        final amt = (r['amount'] as num?)?.toDouble() ?? 0;
        final src = r['source'] as String? ?? '';
        if (src == 'appointment') {
          commSvc += amt;
        } else if (src == 'product_sale') {
          commProd += amt;
        }
      }

      // Build monthly breakdown with actual withheld amounts
      final monthlyRev = <int, double>{};
      final monthlyIsr = <int, double>{};
      final monthlyIva = <int, double>{};
      final monthlyExp = <int, double>{};
      for (final r in revenueRows) {
        final startStr = r['starts_at'] as String?;
        if (startStr == null) continue;
        final dt = DateTime.tryParse(startStr);
        if (dt == null) continue;
        monthlyRev[dt.month] = (monthlyRev[dt.month] ?? 0) + ((r['price'] as num?)?.toDouble() ?? 0);
        monthlyIsr[dt.month] = (monthlyIsr[dt.month] ?? 0) + ((r['isr_withheld'] as num?)?.toDouble() ?? 0);
        monthlyIva[dt.month] = (monthlyIva[dt.month] ?? 0) + ((r['iva_withheld'] as num?)?.toDouble() ?? 0);
      }
      for (final r in expRows) {
        final m = r['month'] as int?;
        if (m == null) continue;
        monthlyExp[m] = (monthlyExp[m] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
      }

      final months = <Map<String, dynamic>>[];
      const monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final currentMonth = DateTime.now().month;
      for (int m = 1; m <= currentMonth; m++) {
        final mRev = monthlyRev[m] ?? 0;
        final mExp = monthlyExp[m] ?? 0;
        months.add({
          'month': monthNames[m],
          'revenue': mRev,
          'iva': monthlyIva[m] ?? 0,
          'isr': monthlyIsr[m] ?? 0,
          'expenses': mExp,
          'cfdi': mRev > 0 ? 'pendiente' : 'n/a',
        });
      }

      if (mounted) {
        setState(() {
          _revenueYtd = rev;
          _ivaWithheld = actualIva;
          _isrWithheld = actualIsr;
          _expensesYtd = exp;
          _expenseRows = List<Map<String, dynamic>>.from(expRows);
          _commissionServices = commSvc;
          _commissionProducts = commProd;
          _monthlyData.clear();
          _monthlyData.addAll(months);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) => NumberFormat('#,##0', 'es_MX').format(v);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bcExt = Theme.of(context).extension<BCThemeExtension>()!;

    if (_loading) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
        ),
      );
    }

    final totalTaxPaidByBC = _ivaWithheld + _isrWithheld;

    // BeautyCita retains half of IVA (8%) and partial ISR (2.5%) per law.
    // The salon MUST pay the other half directly to SAT.
    // IVA: full 16%, BC retains 8%, salon owes 8%
    // ISR: varies by income bracket, BC retains 2.5%, salon owes the rest
    final salonIvaObligation = _ivaWithheld; // same 8% — the other half
    final salonIsrEstimate = _isrWithheld; // actual ISR withheld from appointments
    final salonTotalOwed = salonIvaObligation + salonIsrEstimate;

    // Deduction budget: expenses reduce TAXABLE INCOME, which reduces the salon's
    // remaining ISR obligation. Only valid IF the salon pays their half.
    final taxableIncome = (_revenueYtd - _expensesYtd).clamp(0.0, double.infinity).toDouble();
    final deductionBudget = taxableIncome;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingSM),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance_outlined, size: 20, color: bcExt.successColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Impuestos y Deducciones',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
                      Text('Ano ${DateTime.now().year}',
                        style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 20),
                  tooltip: 'Exportar CSV',
                  color: colors.primary,
                  onPressed: () => _exportTaxCsv(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Revenue
            _TaxRow(label: 'Ingresos registrados', value: '\$${_fmt(_revenueYtd)}', color: colors.onSurface, bold: true),
            const SizedBox(height: 8),

            // What BeautyCita already paid to SAT on their behalf
            _TaxRow(label: 'IVA retenido por BC (50% de 16%)', value: '\$${_fmt(_ivaWithheld)}', color: bcExt.successColor),
            const SizedBox(height: 4),
            _TaxRow(label: 'ISR retenido por BC (Art. 113-A)', value: '\$${_fmt(_isrWithheld)}', color: bcExt.successColor),
            const SizedBox(height: 4),
            _TaxRow(label: 'Total pagado por BC a SAT', value: '\$${_fmt(totalTaxPaidByBC)}', color: bcExt.successColor, bold: true),

            Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),

            // ⚠️ What the salon STILL OWES SAT directly
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: bcExt.warningColor),
                      const SizedBox(width: 6),
                      Text('TU OBLIGACION DIRECTA CON SAT',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: bcExt.warningColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'BeautyCita retiene solo la mitad. Tu debes pagar el resto directamente al SAT.',
                    style: GoogleFonts.nunito(fontSize: 11, color: bcExt.warningColor, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _TaxRow(label: 'IVA que TU debes (otro 8%)', value: '\$${_fmt(salonIvaObligation)}', color: bcExt.warningColor),
            const SizedBox(height: 4),
            _TaxRow(label: 'ISR estimado que TU debes', value: '\$${_fmt(salonIsrEstimate)}', color: bcExt.warningColor),
            const SizedBox(height: 4),
            _TaxRow(label: 'Total estimado que debes a SAT', value: '\$${_fmt(salonTotalOwed)}', color: bcExt.warningColor, bold: true),

            Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),

            // Deductions
            GestureDetector(
              onTap: _expenseRows.isNotEmpty ? () => _showExpenseList(context) : null,
              child: _TaxRow(label: 'Gastos deducibles registrados', value: '\$${_fmt(_expensesYtd)}', color: colors.secondary,
                trailing: _expenseRows.isNotEmpty ? Icon(Icons.chevron_right, size: 16, color: colors.secondary) : null),
            ),
            const SizedBox(height: 4),
            _TaxRow(
              label: 'Presupuesto deducible disponible',
              value: '\$${_fmt(deductionBudget)}',
              color: colors.secondary,
              bold: true,
            ),
            const SizedBox(height: 8),

            // Deduction tip
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Muebles, herramientas, gasolina, renta, internet — todo gasto de negocio con factura es 100% deducible. '
                    'Puedes gastar hasta \$${_fmt(deductionBudget)} mas para reducir tu ISR.\n\n'
                    'IMPORTANTE: Este calculo asume que pagas tu mitad de impuestos al SAT. '
                    'Si no pagas, las deducciones no aplican.',
                    style: GoogleFonts.nunito(fontSize: 11, color: colors.secondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 14, color: const Color(0xFF7C3AED).withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Fecha limite para deducciones ${DateTime.now().year}: 31 de Diciembre ${DateTime.now().year}',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: colors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Days remaining progress
                  Builder(builder: (context) {
                    final now = DateTime.now();
                    final yearEnd = DateTime(now.year, 12, 31);
                    final yearStart = DateTime(now.year, 1, 1);
                    final totalDays = yearEnd.difference(yearStart).inDays;
                    final daysLeft = yearEnd.difference(now).inDays;
                    final progress = 1.0 - (daysLeft / totalDays);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            color: daysLeft < 60 ? colors.error : colors.secondary,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$daysLeft dias restantes para deducir gastos de ${now.year}',
                          style: GoogleFonts.nunito(fontSize: 10, color: const Color(0xFF7C3AED).withValues(alpha: 0.7)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            // ── Commission Transparency ──
            Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.percent_rounded, size: 16, color: Color(0xFFEC4899)),
                ),
                const SizedBox(width: 8),
                Text('Comisiones BeautyCita',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            _TaxRow(label: 'Comision BC (3% servicios)', value: '\$${_fmt(_commissionServices)}', color: const Color(0xFFEC4899)),
            const SizedBox(height: 4),
            _TaxRow(label: 'Comision BC (10% productos)', value: '\$${_fmt(_commissionProducts)}', color: const Color(0xFFEC4899)),
            const SizedBox(height: 4),
            _TaxRow(
              label: 'Total comisiones ${DateTime.now().year}',
              value: '\$${_fmt(_commissionServices + _commissionProducts)}',
              color: const Color(0xFFEC4899),
              bold: true,
            ),

            // ── Monthly SAT History ──
            if (_monthlyData.isNotEmpty) ...[
              Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),
              Text('HISTORIAL MENSUAL SAT',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: colors.onSurface.withValues(alpha: 0.4),
                )),
              const SizedBox(height: 8),
              ...List.generate(_monthlyData.length, (i) {
                final m = _monthlyData[i];
                final rev = m['revenue'] as double;
                final iva = m['iva'] as double;
                final isr = m['isr'] as double;
                final exp = m['expenses'] as double;
                final cfdi = m['cfdi'] as String;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m['month'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurface)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cfdi == 'pendiente'
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : const Color(0xFF059669).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cfdi == 'pendiente' ? 'CFDI Pendiente' : cfdi == 'n/a' ? 'Sin actividad' : 'CFDI Emitido',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cfdi == 'pendiente' ? bcExt.warningColor : bcExt.successColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: _MiniStat(label: 'Ingreso', value: '\$${_fmt(rev)}', color: colors.onSurface)),
                          Expanded(child: _MiniStat(label: 'IVA 8%', value: '\$${_fmt(iva)}', color: bcExt.successColor)),
                          Expanded(child: _MiniStat(label: 'ISR 2.5%', value: '\$${_fmt(isr)}', color: bcExt.successColor)),
                          Expanded(child: _MiniStat(label: 'Gastos', value: '\$${_fmt(exp)}', color: colors.secondary)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            // ── Revenue Trend Chart ──
            if (_monthlyData.isNotEmpty) ...[
              Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),
              TrendChart(
                title: 'Ingresos Mensuales',
                type: TrendChartType.bar,
                color: bcExt.successColor,
                height: 160,
                valuePrefix: '\$',
                data: _monthlyData.map((m) => TrendPoint(
                  m['month'] as String,
                  (m['revenue'] as double),
                )).toList(),
              ),
            ],

            const SizedBox(height: 14),

            // Add expense button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddExpenseSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Registrar Gasto Deducible',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.secondary,
                  side: BorderSide(color: colors.secondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportTaxCsv(BuildContext context) {
    CsvExporter.exportMaps(
      context: context,
      filename: 'impuestos_deducciones',
      headers: ['Mes', 'Ingresos', 'IVA 8%', 'ISR 2.5%', 'Gastos', 'CFDI'],
      keys: ['month', 'revenue', 'iva', 'isr', 'expenses', 'cfdi'],
      items: _monthlyData,
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final colors = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Registrar Gasto Deducible',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(height: 6),
                Text(
                  'Ingresa el monto total de gastos de negocio con factura. '
                  'Ejemplo: herramientas, productos, renta, servicios, gasolina.',
                  style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5), height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Monto (MXN)',
                    prefixText: '\$ ',
                    prefixStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: colors.secondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.secondary, width: 2),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: GoogleFonts.nunito(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Descripcion (opcional)',
                    hintText: 'Ej: Productos para el salon, renta marzo...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.secondary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '').trim());
                    if (amount == null || amount <= 0) {
                      ToastService.showWarning('Ingresa un monto valido');
                      return;
                    }
                    setSheetState(() => saving = true);
                    try {
                      final biz = await ref.read(currentBusinessProvider.future);
                      if (biz == null) throw Exception('No business');
                      final now = DateTime.now();
                      await SupabaseClientService.client.from(BCTables.businessExpenses).insert({
                        'business_id': biz['id'],
                        'amount': amount,
                        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        'month': now.month,
                        'year': now.year,
                      });
                      ToastService.showSuccess('Gasto registrado: \$${NumberFormat('#,##0', 'es_MX').format(amount)}');
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData(); // refresh the card
                    } catch (e) {
                      ToastService.showErrorWithDetails('Error al guardar', e, StackTrace.current);
                    } finally {
                      if (ctx.mounted) setSheetState(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.secondary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: saving
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                    : Text('Guardar', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExpenseList(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.8,
            minChildSize: 0.3,
            builder: (ctx, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Gastos Registrados',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _expenseRows.isEmpty
                      ? Center(child: Text('Sin gastos registrados', style: GoogleFonts.nunito(color: colors.onSurface.withValues(alpha: 0.5))))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: _expenseRows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (ctx, i) {
                            final row = _expenseRows[i];
                            final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                            final desc = row['description'] as String?;
                            final month = row['month'] as int? ?? 0;
                            final fmt = NumberFormat('#,##0', 'es_MX');
                            return Dismissible(
                              key: Key(row['id'] as String),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    title: Text('Eliminar gasto', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                    content: Text('Eliminar \$${fmt.format(amount)}${desc != null ? ' ($desc)' : ''}?',
                                      style: GoogleFonts.nunito()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: Text('Eliminar', style: TextStyle(color: colors.error)),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                              },
                              onDismissed: (_) async {
                                final id = row['id'] as String;
                                setSheetState(() => _expenseRows.removeAt(i));
                                try {
                                  await SupabaseClientService.client
                                      .from(BCTables.businessExpenses)
                                      .delete()
                                      .eq('id', id);
                                  ToastService.showSuccess('Gasto eliminado');
                                  _loadData();
                                } catch (e) {
                                  ToastService.showErrorWithDetails('Error al eliminar', e, StackTrace.current);
                                  _loadData();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('\$${fmt.format(amount)}',
                                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: colors.secondary)),
                                          if (desc != null && desc.isNotEmpty)
                                            Text(desc, style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Text(month > 0 && month <= 12 ? monthNames[month] : '',
                                      style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                                    const SizedBox(width: 4),
                                    Icon(Icons.swipe_left_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.nunito(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        Text(value,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final Widget? trailing;

  const _TaxRow({required this.label, required this.value, required this.color, this.bold = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
              style: GoogleFonts.poppins(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
            ?trailing,
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CFDI Records Section
// ═══════════════════════════════════════════════════════════════════════════

class _CfdiSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CfdiSection> createState() => _CfdiSectionState();
}

class _CfdiSectionState extends ConsumerState<_CfdiSection> {
  List<Map<String, dynamic>> _cfdiRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCfdis();
  }

  Future<void> _loadCfdis() async {
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) return;
      final bizId = biz['id'] as String;

      // Use tax_withholdings as CFDI proxy (real CFDIs need PAC integration)
      // Group by month to show monthly summary
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);

      final data = await SupabaseClientService.client
          .from(BCTables.taxWithholdings)
          .select('period_year, period_month, gross_amount, isr_withheld, iva_withheld')
          .eq('business_id', bizId)
          .gte('created_at', threeMonthsAgo.toIso8601String())
          .order('created_at', ascending: false);

      // Aggregate by month
      final monthMap = <String, Map<String, dynamic>>{};
      for (final r in (data as List)) {
        final key = '${r['period_year']}-${r['period_month']}';
        final existing = monthMap[key] ?? {
          'period_year': r['period_year'],
          'period_month': r['period_month'],
          'total_gross': 0.0,
          'total_isr': 0.0,
          'total_iva': 0.0,
          'count': 0,
        };
        existing['total_gross'] = (existing['total_gross'] as double) + ((r['gross_amount'] as num?)?.toDouble() ?? 0);
        existing['total_isr'] = (existing['total_isr'] as double) + ((r['isr_withheld'] as num?)?.toDouble() ?? 0);
        existing['total_iva'] = (existing['total_iva'] as double) + ((r['iva_withheld'] as num?)?.toDouble() ?? 0);
        existing['count'] = (existing['count'] as int) + 1;
        monthMap[key] = existing;
      }

      if (mounted) {
        setState(() {
          _cfdiRecords = monthMap.values.toList()
            ..sort((a, b) {
              final ya = a['period_year'] as int;
              final yb = b['period_year'] as int;
              if (ya != yb) return yb.compareTo(ya);
              return (b['period_month'] as int).compareTo(a['period_month'] as int);
            });
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) => NumberFormat('#,##0.00', 'es_MX').format(v);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
        ),
      );
    }

    if (_cfdiRecords.isEmpty) {
      return Card(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 36, color: colors.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              Text('Sin CFDI registrados',
                  style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
              Text('Los comprobantes fiscales apareceran aqui',
                  style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingSM),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Comprobantes Fiscales (CFDI)',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('APROX',
                                style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w800, color: colors.secondary)),
                          ),
                        ],
                      ),
                      Text('${_cfdiRecords.length} registro${_cfdiRecords.length == 1 ? '' : 's'}',
                          style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._cfdiRecords.map((rec) {
              const monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
              final year = rec['period_year'] as int? ?? 0;
              final month = rec['period_month'] as int? ?? 0;
              final gross = (rec['total_gross'] as double?) ?? 0;
              final isr = (rec['total_isr'] as double?) ?? 0;
              final iva = (rec['total_iva'] as double?) ?? 0;
              final count = rec['count'] as int? ?? 0;
              final monthLabel = month > 0 && month <= 12 ? monthNames[month] : '?';

              return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$monthLabel $year — $count transacciones',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface),
                            ),
                            Text(
                              'ISR: \$${_fmt(isr)} | IVA: \$${_fmt(iva)}',
                              style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${_fmt(gross)}',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CFDI pendiente',
                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCfdiDetail(BuildContext context, Map<String, dynamic> cfdi) {
    final colors = Theme.of(context).colorScheme;
    final folio = cfdi['folio'] as String?;
    final uuidFiscal = cfdi['uuid_fiscal'] as String?;
    final period = cfdi['period'] as String? ?? '';
    final status = cfdi['status'] as String? ?? 'pendiente';
    final subtotal = (cfdi['subtotal'] as num?)?.toDouble() ?? 0;
    final iva = (cfdi['iva'] as num?)?.toDouble() ?? 0;
    final total = (cfdi['total'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalle CFDI',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface)),
            const SizedBox(height: 16),
            _CfdiDetailRow(label: 'Periodo', value: period),
            _CfdiDetailRow(label: 'Estado', value: status == 'timbrado' ? 'Timbrado' : 'Pendiente'),
            if (folio != null) _CfdiDetailRow(label: 'Folio', value: folio),
            if (uuidFiscal != null) _CfdiDetailRow(label: 'UUID Fiscal', value: uuidFiscal),
            const Divider(height: 20),
            _CfdiDetailRow(label: 'Subtotal', value: '\$${_fmt(subtotal)}'),
            _CfdiDetailRow(label: 'IVA', value: '\$${_fmt(iva)}'),
            _CfdiDetailRow(label: 'Total', value: '\$${_fmt(total)}', bold: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CfdiDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _CfdiDetailRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
          Flexible(
            child: Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Banking Setup Banner — shown when banking_complete == false
// ═══════════════════════════════════════════════════════════════════════════

class _BankingBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bankingAsync = ref.watch(bankingCompleteProvider);

    return bankingAsync.when(
      data: (complete) {
        if (complete) return const SizedBox.shrink();

        final warnColor = Theme.of(context).extension<BCThemeExtension>()!.warningColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: warnColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(color: warnColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingSM),
                  decoration: BoxDecoration(
                    color: warnColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  ),
                  child: Icon(Icons.account_balance_outlined,
                      color: warnColor, size: 22),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completa tu informacion bancaria para activar reservas y recibir pagos',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: warnColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingSM),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BankingSetupScreen(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Completar ahora',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: warnColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 16, color: warnColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
