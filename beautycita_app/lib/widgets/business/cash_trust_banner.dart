// =============================================================================
// CashTrustBanner — Salon panel banner shown when cash payments are blocked
// =============================================================================
// Renders only when businesses.cash_blocked_at IS NOT NULL. Shows the open
// tax_obligation debt + a "Pagar ahora" CTA that opens the payment sheet
// (debit card / OXXO via Stripe).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../config/fonts.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

final _openTaxDebtProvider =
    FutureProvider.autoDispose.family<double, String>((ref, businessId) async {
  if (businessId.isEmpty) return 0;
  final rows = await SupabaseClientService.client
      .from('salon_debts')
      .select('remaining_amount')
      .eq('business_id', businessId)
      .eq('debt_type', 'tax_obligation')
      .gt('remaining_amount', 0);
  double sum = 0;
  for (final r in rows as List) {
    sum += ((r as Map)['remaining_amount'] as num?)?.toDouble() ?? 0;
  }
  return sum;
});

class CashTrustBanner extends ConsumerWidget {
  const CashTrustBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      data: (biz) {
        if (biz == null) return const SizedBox.shrink();
        final blockedAt = biz['cash_blocked_at'];
        if (blockedAt == null) return const SizedBox.shrink();

        final businessId = biz['id'] as String;
        final debtAsync = ref.watch(_openTaxDebtProvider(businessId));
        final debt = debtAsync.valueOrNull ?? 0;

        final colors = Theme.of(context).colorScheme;
        final warnColor = colors.error;

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppConstants.paddingMD, 0, AppConstants.paddingMD, AppConstants.paddingMD),
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            color: warnColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: warnColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: warnColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.money_off_csred_rounded, color: warnColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pagos en efectivo desactivados',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: warnColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tienes un adeudo fiscal de \$${NumberFormat('#,##0.00', 'es_MX').format(debt)} MXN '
                'con BeautyCita. Mientras este pendiente, los clientes no pueden pagar en efectivo.',
                style: GoogleFonts.nunito(fontSize: 12, color: warnColor, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: warnColor,
                        foregroundColor: colors.onError,
                      ),
                      icon: const Icon(Icons.credit_card_rounded, size: 18),
                      label: const Text('Pagar ahora'),
                      onPressed: debt > 0
                          ? () => _openPaymentSheet(context, ref, businessId, debt)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _openPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    String businessId,
    double debt,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CashTrustPaymentSheet(businessId: businessId, openDebt: debt),
    );
    // Refresh after sheet closes (payment may have just succeeded).
    ref.invalidate(currentBusinessProvider);
    ref.invalidate(_openTaxDebtProvider(businessId));
  }
}

class CashTrustPaymentSheet extends ConsumerStatefulWidget {
  final String businessId;
  final double openDebt;
  const CashTrustPaymentSheet({super.key, required this.businessId, required this.openDebt});

  @override
  ConsumerState<CashTrustPaymentSheet> createState() => _CashTrustPaymentSheetState();
}

class _CashTrustPaymentSheetState extends ConsumerState<CashTrustPaymentSheet> {
  String _method = 'card';
  bool _processing = false;

  Future<void> _pay() async {
    setState(() => _processing = true);
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'create-tax-debt-payment',
        body: {'business_id': widget.businessId, 'payment_method': _method},
      );
      final data = res.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw Exception(data['error'] as String);
      }

      final clientSecret = data['client_secret'] as String? ?? '';
      final customerId = data['customer_id'] as String? ?? '';
      final ephemeralKey = data['ephemeral_key'] as String? ?? '';
      if (clientSecret.isEmpty) throw Exception('Error al iniciar pago');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          merchantDisplayName: 'BeautyCita — Pago de retencion fiscal',
          returnURL: 'beautycita://stripe-redirect',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      if (mounted) {
        Navigator.pop(context);
        if (_method == 'oxxo') {
          ToastService.showInfo(
              'Voucher generado. Paga en OXXO en los proximos 3 dias para reactivar pagos en efectivo.');
        } else {
          ToastService.showSuccess(
              'Pago recibido. Pagos en efectivo se reactivaran al confirmarse.');
        }
      }
    } on StripeException {
      if (mounted) ToastService.showInfo('Pago cancelado');
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) ToastService.showError('Error: $msg');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pagar adeudo fiscal',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total a pagar: \$${NumberFormat('#,##0.00', 'es_MX').format(widget.openDebt)} MXN',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text('METODO DE PAGO',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.onSurface.withValues(alpha: 0.5),
              )),
          const SizedBox(height: 10),
          _MethodTile(
            icon: Icons.credit_card_rounded,
            label: 'Tarjeta de debito o credito',
            subtitle: 'Pago inmediato',
            selected: _method == 'card',
            onTap: () => setState(() => _method = 'card'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _MethodTile(
            icon: Icons.store_rounded,
            label: 'Deposito en OXXO',
            subtitle: 'Voucher con 3 dias para pagar',
            selected: _method == 'oxxo',
            onTap: () => setState(() => _method = 'oxxo'),
            colors: colors,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _processing ? null : _pay,
              child: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Continuar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Al pagar, BeautyCita liquidara tu adeudo SAT y los pagos en efectivo de tus clientes se reactivaran automaticamente.',
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.55),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.08) : colors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      )),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
