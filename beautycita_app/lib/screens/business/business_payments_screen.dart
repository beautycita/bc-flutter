import 'package:flutter/foundation.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
// ignore: depend_on_referenced_packages
import 'package:beautycita/widgets/admin/admin_widgets.dart';

class BusinessPaymentsScreen extends ConsumerStatefulWidget {
  const BusinessPaymentsScreen({super.key});

  @override
  ConsumerState<BusinessPaymentsScreen> createState() =>
      _BusinessPaymentsScreenState();
}

class _BusinessPaymentsScreenState
    extends ConsumerState<BusinessPaymentsScreen> {
  bool _syncedStripe = false;
  DateTime? _txDateFrom;
  DateTime? _txDateTo;

  List<Map<String, dynamic>> _filterTransactions(List<Map<String, dynamic>> payments) {
    if (_txDateFrom == null && _txDateTo == null) return payments;
    return payments.where((p) {
      final createdAt = p['created_at'] as String?;
      if (createdAt == null) return true;
      final dt = DateTime.tryParse(createdAt);
      if (dt == null) return true;
      if (_txDateFrom != null && dt.isBefore(_txDateFrom!)) return false;
      if (_txDateTo != null && dt.isAfter(_txDateTo!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
  }

  void _exportTransactionsCsv(BuildContext context, List<Map<String, dynamic>> payments) {
    CsvExporter.exportMaps(
      context: context,
      filename: 'transacciones',
      headers: ['Fecha', 'Tipo', 'Monto', 'Estado', 'Referencia'],
      keys: ['created_at', 'type', 'amount', 'status', 'reference'],
      items: payments,
    );
  }

  void _exportPayoutsCsv(BuildContext context, List<Map<String, dynamic>> payouts) {
    CsvExporter.exportMaps(
      context: context,
      filename: 'pagos',
      headers: ['Fecha', 'Monto', 'Metodo', 'Referencia', 'Estado'],
      keys: ['created_at', 'amount', 'method', 'reference', 'status'],
      items: payouts,
    );
  }

  @override
  void initState() {
    super.initState();
    // Auto-sync Stripe status from Stripe API when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStripeStatus());
  }

  Future<void> _syncStripeStatus() async {
    if (_syncedStripe) return;
    _syncedStripe = true;
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) return;
      final bizId = biz['id'] as String;
      final hasStripe = biz['stripe_account_id'] != null;
      if (!hasStripe) return;

      // Call edge function to sync latest status from Stripe
      await SupabaseClientService.client.functions.invoke(
        'stripe-connect-onboard',
        body: {'action': 'get-account-status', 'business_id': bizId},
      );
      // Refresh the business provider so UI picks up new status
      ref.invalidate(currentBusinessProvider);
    } catch (e) {
      if (kDebugMode) debugPrint('Stripe status sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final paymentsAsync = ref.watch(businessPaymentsProvider);
    final payoutsAsync = ref.watch(businessPayoutsProvider);
    final statsAsync = ref.watch(businessStatsProvider);
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        _syncedStripe = false;
        _syncStripeStatus();
        ref.invalidate(businessPaymentsProvider);
        ref.invalidate(businessStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          // Stripe status banner
          bizAsync.when(
            data: (biz) {
              if (biz == null) return const SizedBox.shrink();
              final stripeStatus =
                  biz['stripe_onboarding_status'] as String? ?? 'not_started';
              final chargesEnabled =
                  biz['stripe_charges_enabled'] as bool? ?? false;
              final payoutsEnabled =
                  biz['stripe_payouts_enabled'] as bool? ?? false;

              if (chargesEnabled && payoutsEnabled) {
                return _StatusBanner(
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  label: 'Stripe conectado — Pagos y transferencias activos',
                );
              }

              return Column(
                children: [
                  _StatusBanner(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    label: stripeStatus == 'not_started'
                        ? 'Conecta Stripe para recibir pagos'
                        : 'Onboarding de Stripe pendiente',
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchStripeOnboarding(context, ref, biz),
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Conectar Stripe'),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Error al cargar', style: TextStyle(color: Colors.red.shade400, fontSize: 13))),
            ),
          ),

          // Revenue summary
          statsAsync.when(
            data: (stats) => Card(
              elevation: 0,
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                side: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingresos del Mes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${stats.revenueMonth.toStringAsFixed(0)} MXN',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
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

          const SizedBox(height: AppConstants.paddingLG),

          // Transaction history
          Text(
            'Transacciones Recientes',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          paymentsAsync.when(
            data: (payments) {
              final filtered = _filterTransactions(payments);
              // AdminToolbar: date range + export for transactions
              return Column(
                children: [
                  AdminToolbar(
                    showDateRange: true,
                    dateFrom: _txDateFrom,
                    dateTo: _txDateTo,
                    onDateRangeTap: () async {
                      final range = await showAdminDateRangePicker(context,
                          initialFrom: _txDateFrom, initialTo: _txDateTo);
                      if (range != null) {
                        setState(() {
                          _txDateFrom = range.start;
                          _txDateTo = range.end;
                        });
                      }
                    },
                    onDateRangeClear: () => setState(() {
                      _txDateFrom = null;
                      _txDateTo = null;
                    }),
                    showExport: true,
                    onExport: () => _exportTransactionsCsv(context, filtered),
                    totalCount: payments.length,
                    filteredCount: filtered.length,
                  ),
                  if (filtered.isEmpty) ...[ Card(
                    elevation: 0,
                    color: colors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingXL),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: colors.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: AppConstants.paddingSM),
                          Text(
                            'Sin transacciones',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )]
                  else
                    ...filtered.map((p) => _PaymentCard(payment: p)),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: GoogleFonts.nunito(color: colors.error)),
          ),

          // placeholder when block below needs to stay distinct
          const SizedBox(height: AppConstants.paddingLG),

          // ── Payout History ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historial de Pagos',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
              payoutsAsync.when(
                data: (payouts) => IconButton(
                  icon: const Icon(Icons.download_rounded, size: 20),
                  tooltip: 'Exportar pagos CSV',
                  color: colors.primary,
                  onPressed: () => _exportPayoutsCsv(context, payouts),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSM),

          payoutsAsync.when(
            data: (payouts) {
              if (payouts.isEmpty) {
                return Card(
                  elevation: 0,
                  color: colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingXL),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: colors.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: AppConstants.paddingSM),
                        Text(
                          'Sin pagos registrados',
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
                children: payouts.map((p) => _PayoutCard(payout: p)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: GoogleFonts.nunito(color: colors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchStripeOnboarding(
      BuildContext context, WidgetRef ref, Map<String, dynamic> biz) async {
    final bizId = biz['id'] as String;
    final navigator = Navigator.of(context, rootNavigator: true);

    showBurstDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'stripe-connect-onboard',
        body: {'action': 'get-onboard-link', 'business_id': bizId},
      );

      navigator.pop(); // dismiss loading

      final data = response.data as Map<String, dynamic>?;
      final url = data?['onboarding_url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception(
            data?['error'] as String? ?? 'No se genero el enlace de Stripe');
      }

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

      // Refresh status when user returns
      ref.invalidate(currentBusinessProvider);
    } catch (e, stack) {
      try {
        navigator.pop();
      } catch (e2) {
        if (kDebugMode) debugPrint('[Payments] navigator.pop() failed: $e2');
      }
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppConstants.paddingSM),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _PaymentsDetailRow(String label, String? value) => Padding(
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
            color: Colors.grey[600],
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
);

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final status = payment['status'] as String? ?? 'unknown';
    final type = payment['type'] as String? ?? 'payment';
    final createdAt = payment['created_at'] as String?;

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      }
    }

    final isRefund = type == 'refund';
    final typeLabel = _typeLabel(type);
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Card(
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRefund ? Icons.undo_rounded : Icons.payment_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          '${isRefund ? '-' : '+'}\$${amount.toStringAsFixed(0)} MXN',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isRefund ? Colors.red : colors.onSurface,
          ),
        ),
        subtitle: Text(
          '$typeLabel • $dateStr',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
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
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Detalle Transaccion',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...payment.entries.map((e) {
              String val;
              if (e.value == null) {
                val = '—';
              } else if (e.key.endsWith('_at') && e.value is String) {
                final dt = DateTime.tryParse(e.value as String)?.toLocal();
                val = dt != null
                    ? '${dt.day}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
                      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                    : e.value.toString();
              } else {
                val = e.value.toString();
              }
              return _PaymentsDetailRow(e.key, val);
            }),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'payment':
        return 'Pago';
      case 'refund':
        return 'Reembolso';
      case 'payout':
        return 'Transferencia';
      case 'platform_fee':
        return 'Comision';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'succeeded':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _PayoutCard extends StatelessWidget {
  final Map<String, dynamic> payout;
  const _PayoutCard({required this.payout});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final amount = (payout['amount'] as num?)?.toDouble() ?? 0;
    final status = payout['status'] as String? ?? 'pending';
    final method = payout['method'] as String? ?? 'bank_transfer';
    final reference = payout['reference_number'] as String? ?? '';
    final month = payout['period_month'] as int?;
    final year = payout['period_year'] as int?;
    final processedAt = payout['processed_at'] as String?;
    final createdAt = payout['created_at'] as String?;

    String periodStr = '';
    if (month != null && year != null) {
      const monthNames = [
        '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      periodStr = '${monthNames[month.clamp(1, 12)]} $year';
    }

    String dateStr = '';
    final dateSource = processedAt ?? createdAt;
    if (dateSource != null) {
      final dt = DateTime.tryParse(dateSource);
      if (dt != null) {
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      }
    }

    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.grey;

    final methodLabel = method == 'bank_transfer' ? 'Transferencia' : method;

    return GestureDetector(
      onTap: () => _showDetail(context, payout),
      child: Card(
        elevation: 0,
        color: colors.surface,
        margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
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
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_balance_rounded,
                        color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${amount.toStringAsFixed(2)} MXN',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          '$methodLabel${periodStr.isNotEmpty ? ' • $periodStr' : ''}',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status == 'completed' ? 'Completado' : status == 'pending' ? 'Pendiente' : status,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (reference.isNotEmpty || dateStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (reference.isNotEmpty)
                      Expanded(
                        child: Text(
                          'Ref: $reference',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data) {
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
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Detalle Pago / Retiro',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...data.entries.map((e) {
              String val;
              if (e.value == null) {
                val = '—';
              } else if (e.key.endsWith('_at') && e.value is String) {
                final dt = DateTime.tryParse(e.value as String)?.toLocal();
                val = dt != null
                    ? '${dt.day}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
                      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                    : e.value.toString();
              } else {
                val = e.value.toString();
              }
              return _PaymentsDetailRow(e.key, val);
            }),
          ],
        ),
      ),
    );
  }
}
