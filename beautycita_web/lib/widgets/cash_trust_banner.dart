// =============================================================================
// CashTrustBanner (web) — Salon panel banner when cash is suspended
// =============================================================================
// Matches mobile counterpart. Reads businesses.cash_blocked_at; if set, shows
// the open tax_obligation total + "Pagar ahora" CTA that opens a hosted
// Stripe Checkout session in a new tab.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/business_portal_provider.dart';

final _openTaxDebtProvider =
    FutureProvider.autoDispose.family<double, String>((ref, businessId) async {
  if (businessId.isEmpty) return 0;
  final rows = await BCSupabase.client
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
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (biz) {
        if (biz == null) return const SizedBox.shrink();
        final blockedAt = biz['cash_blocked_at'];
        if (blockedAt == null) return const SizedBox.shrink();
        final businessId = biz['id'] as String;
        final debt = ref.watch(_openTaxDebtProvider(businessId)).valueOrNull ?? 0;

        const warn = Color(0xFFE53935);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: warn.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: warn.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.money_off_csred_rounded, color: warn, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pagos en efectivo desactivados',
                        style: TextStyle(fontWeight: FontWeight.w700, color: warn, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Adeudo fiscal pendiente: \$${debt.toStringAsFixed(2)} MXN. '
                        'Mientras este pendiente, los clientes no pueden pagar en efectivo en tu salon.',
                        style: const TextStyle(color: warn, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: warn),
                        icon: const Icon(Icons.credit_card_rounded, size: 18),
                        label: const Text('Pagar ahora'),
                        onPressed: debt > 0
                            ? () => _payNow(context, ref, businessId)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _payNow(BuildContext context, WidgetRef ref, String businessId) async {
    try {
      final res = await BCSupabase.client.functions.invoke(
        'create-tax-debt-payment',
        body: {
          'business_id': businessId,
          'flow': 'checkout',
          'payment_method': 'card',
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw Exception(data['error'] as String);
      }
      final url = data['url'] as String? ?? '';
      if (url.isEmpty) throw Exception('No se obtuvo url de pago');
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }
}
