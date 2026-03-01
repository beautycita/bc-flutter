import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class BusinessPaymentsScreen extends ConsumerStatefulWidget {
  const BusinessPaymentsScreen({super.key});

  @override
  ConsumerState<BusinessPaymentsScreen> createState() =>
      _BusinessPaymentsScreenState();
}

class _BusinessPaymentsScreenState
    extends ConsumerState<BusinessPaymentsScreen> {
  bool _syncedStripe = false;

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
      debugPrint('Stripe status sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final paymentsAsync = ref.watch(businessPaymentsProvider);
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
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
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
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
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
              if (payments.isEmpty) {
                return Card(
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
                );
              }

              return Column(
                children: payments.map((p) => _PaymentCard(payment: p)).toList(),
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

    showDialog(
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
      } catch (_) {}
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
