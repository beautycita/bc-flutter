import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/providers/payment_methods_provider.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(paymentMethodsProvider.notifier).loadCards();
    });
  }

  void _showCashInfo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLG)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSheetHeader(context, 'Pago en efectivo'),
                const SizedBox(height: 8),
                _CashInfoStep(number: 1, text: 'Al reservar tu cita, selecciona "Efectivo" como metodo de pago.'),
                _CashInfoStep(number: 2, text: 'Recibiras un codigo de deposito con el monto exacto.'),
                _CashInfoStep(number: 3, text: 'Acude a cualquier OXXO o 7-Eleven y deposita con el codigo.'),
                _CashInfoStep(number: 4, text: 'Tu cita se confirma automaticamente al recibir el pago.', isLast: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El codigo tambien se enviara a tu correo electronico.',
                          style: textTheme.bodySmall?.copyWith(color: cs.primary),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final pm = ref.watch(paymentMethodsProvider);
    final textTheme = Theme.of(context).textTheme;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    // Listen for messages
    ref.listen<PaymentMethodsState>(paymentMethodsProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ToastService.showSuccess(next.successMessage!);
        ref.read(paymentMethodsProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ToastService.showError(next.error!);
        ref.read(paymentMethodsProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Metodos de pago')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Tarjetas guardadas ──
          const SectionHeader(label: 'Tarjetas guardadas'),
          const SizedBox(height: AppConstants.paddingXS),

          if (pm.isLoading && pm.cards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (pm.cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingSM,
                vertical: AppConstants.paddingSM,
              ),
              child: Text(
                'No tienes tarjetas guardadas',
                style: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
              ),
            )
          else
            ...pm.cards.map((card) => _CardTile(card: card, ref: ref)),

          // Add card button
          SettingsTile(
            icon: Icons.add_card_rounded,
            label: 'Agregar tarjeta',
            trailing: pm.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: pm.isLoading ? null : () => ref.read(paymentMethodsProvider.notifier).addCard(),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Otros metodos ──
          const SectionHeader(label: 'Otros metodos'),
          const SizedBox(height: AppConstants.paddingXS),

          // Cash
          _OtherMethodTile(
            icon: Icons.store_rounded,
            iconColor: const Color(0xFFCC0000),
            label: 'Pago en efectivo',
            subtitle: 'OXXO, 7-Eleven, tiendas de conveniencia',
            badgeText: 'Disponible',
            badgeColor: Colors.green.shade600,
            onTap: () => _showCashInfo(context),
          ),

          const SizedBox(height: AppConstants.paddingXS),

          // Bitcoin
          _OtherMethodTile(
            icon: Icons.currency_bitcoin_rounded,
            iconColor: const Color(0xFFF7931A),
            label: 'Bitcoin',
            subtitle: 'Pago con criptomoneda',
            badgeText: 'Disponible',
            badgeColor: Colors.green.shade600,
            onTap: () => context.push(AppRoutes.btcWallet),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Fee info ──
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: onSurfaceLight,
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Text(
                    'BeautyCita cobra una comision del 3% en todas las transacciones para mantener la plataforma y ofrecer proteccion al cliente.',
                    style: textTheme.bodySmall?.copyWith(
                      color: onSurfaceLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final SavedCard card;
  final WidgetRef ref;

  const _CardTile({required this.card, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return SettingsTile(
      icon: Icons.credit_card_rounded,
      iconColor: Colors.green.shade600,
      label: '${card.displayBrand} ****${card.last4}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.expiry,
            style: textTheme.bodySmall?.copyWith(color: onSurfaceLight),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmRemove(context),
            child: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade400),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) async {
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSheetHeader(context, 'Eliminar tarjeta?'),
                Text(
                  '${card.displayBrand} terminada en ${card.last4}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: onSurfaceLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          minimumSize: const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      ref.read(paymentMethodsProvider.notifier).removeCard(card.id);
    }
  }
}

class _OtherMethodTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback? onTap;

  const _OtherMethodTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM,
          vertical: AppConstants.paddingMD,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppConstants.paddingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: onSurfaceLight),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: onSurfaceLight),
            ],
          ],
        ),
      ),
    );
  }
}

class _CashInfoStep extends StatelessWidget {
  final int number;
  final String text;
  final bool isLast;

  const _CashInfoStep({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.08),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Center(
              child: Text(
                '$number',
                style: textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
