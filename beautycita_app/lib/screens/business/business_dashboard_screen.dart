import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

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

          // Tax & Deductions Card
          _TaxDeductionsCard(),

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

// ═══════════════════════════════════════════════════════════════════════════
// Tax & Deductions Dashboard Card
// ═══════════════════════════════════════════════════════════════════════════

class _TaxDeductionsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TaxDeductionsCard> createState() => _TaxDeductionsCardState();
}

class _TaxDeductionsCardState extends ConsumerState<_TaxDeductionsCard> {
  double _revenueYtd = 0;
  double _ivaWithheld = 0;
  double _isrWithheld = 0;
  double _expensesYtd = 0;
  bool _loading = true;

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

      // Revenue YTD from completed appointments
      final revenueRows = await SupabaseClientService.client
          .from('appointments')
          .select('price')
          .eq('business_id', bizId)
          .eq('status', 'completed')
          .gte('starts_at', '$year-01-01');

      double rev = 0;
      for (final r in revenueRows) {
        rev += (r['price'] as num?)?.toDouble() ?? 0;
      }

      // Expenses YTD
      final expRows = await SupabaseClientService.client
          .from('business_expenses')
          .select('amount')
          .eq('business_id', bizId)
          .eq('year', year);

      double exp = 0;
      for (final r in expRows) {
        exp += (r['amount'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _revenueYtd = rev;
          _ivaWithheld = rev * 0.08;
          _isrWithheld = rev * 0.025;
          _expensesYtd = exp;
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

    if (_loading) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
        ),
      );
    }

    final totalTaxPaid = _ivaWithheld + _isrWithheld;
    // Estimated total tax obligation: IVA 16% + ISR ~10% estimate on net
    final estimatedIvaTotal = _revenueYtd * 0.16;
    final estimatedIsrTotal = _revenueYtd * 0.10; // simplified estimate
    final estimatedTotalTax = estimatedIvaTotal + estimatedIsrTotal;
    final taxStillOwed = (estimatedTotalTax - totalTaxPaid).clamp(0, double.infinity);

    // Deduction budget: expenses reduce taxable income
    // The salon can deduct 100% of business expenses
    // Show how much more they could spend to offset remaining tax
    final deductionBudget = (_revenueYtd - _expensesYtd).clamp(0, double.infinity);

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_outlined, size: 20, color: Color(0xFF059669)),
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
              ],
            ),
            const SizedBox(height: 16),

            // Revenue
            _TaxRow(label: 'Ingresos registrados', value: '\$${_fmt(_revenueYtd)}', color: colors.onSurface, bold: true),
            const SizedBox(height: 8),

            // Taxes withheld by BeautyCita
            _TaxRow(label: 'IVA retenido por BC (8%)', value: '\$${_fmt(_ivaWithheld)}', color: const Color(0xFF059669)),
            const SizedBox(height: 4),
            _TaxRow(label: 'ISR retenido por BC (2.5%)', value: '\$${_fmt(_isrWithheld)}', color: const Color(0xFF059669)),
            const SizedBox(height: 4),
            _TaxRow(label: 'Total impuestos pagados', value: '\$${_fmt(totalTaxPaid)}', color: const Color(0xFF059669), bold: true),

            Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),

            // Estimated remaining
            _TaxRow(label: 'IVA pendiente estimado (8%)', value: '\$${_fmt(estimatedIvaTotal - _ivaWithheld)}', color: Colors.orange),
            const SizedBox(height: 4),
            _TaxRow(label: 'ISR pendiente estimado', value: '\$${_fmt(estimatedIsrTotal - _isrWithheld)}', color: Colors.orange),
            const SizedBox(height: 4),
            _TaxRow(label: 'Total estimado por pagar', value: '\$${_fmt(taxStillOwed)}', color: Colors.orange, bold: true),

            Divider(height: 20, color: colors.onSurface.withValues(alpha: 0.08)),

            // Deductions
            _TaxRow(label: 'Gastos deducibles registrados', value: '\$${_fmt(_expensesYtd)}', color: const Color(0xFF7C3AED)),
            const SizedBox(height: 4),
            _TaxRow(
              label: 'Presupuesto deducible disponible',
              value: '\$${_fmt(deductionBudget)}',
              color: const Color(0xFF7C3AED),
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
              child: Text(
                'Muebles, herramientas, gasolina, renta, internet — todo gasto de negocio con factura es 100% deducible. '
                'Puedes gastar hasta \$${_fmt(deductionBudget)} mas y recibir el 100% de regreso via deducciones.',
                style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF7C3AED), height: 1.4),
              ),
            ),

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
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
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
                    prefixStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
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
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
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
                      await SupabaseClientService.client.from('business_expenses').insert({
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
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Guardar', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _TaxRow({required this.label, required this.value, required this.color, this.bold = false});

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
        Text(value,
          style: GoogleFonts.poppins(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
