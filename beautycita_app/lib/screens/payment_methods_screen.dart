import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/providers/payment_methods_provider.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

final _saldoProvider = FutureProvider<double>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return 0;
  final data = await SupabaseClientService.client
      .from('profiles')
      .select('saldo')
      .eq('id', userId)
      .maybeSingle();
  return (data?['saldo'] as num?)?.toDouble() ?? 0;
});

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    const count = 3; // saved cards, other methods, fee info
    _fadeAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _slideAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });
    _entryController.forward();
    Future.microtask(() {
      ref.read(paymentMethodsProvider.notifier).loadCards();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  void _showCashInfo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showBurstBottomSheet(
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

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Metodos de pago')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Saldo (refund credit) ──
          Consumer(
            builder: (context, ref, _) {
              final saldoAsync = ref.watch(_saldoProvider);
              final saldo = saldoAsync.valueOrNull ?? 0.0;
              if (saldo <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Saldo disponible',
                              style: GoogleFonts.nunito(
                                fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                            Text('\$${saldo.toStringAsFixed(2)} MXN',
                              style: GoogleFonts.poppins(
                                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                      Text('Se aplica\nautomaticamente',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.nunito(
                          fontSize: 10, color: Colors.white60, height: 1.3)),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Tarjeta de regalo ──
          _animated(0, const _GiftCardRedemptionTile()),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Tarjetas guardadas ──
          _animated(0, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Tarjetas guardadas'),

              // Grouped card container for saved cards
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  border: Border.all(color: ext.cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (pm.isLoading && pm.cards.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (pm.cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppConstants.paddingMD),
                        child: Text(
                          'No tienes tarjetas guardadas',
                          style: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
                        ),
                      )
                    else
                      ...pm.cards.asMap().entries.map((entry) {
                        final index = entry.key;
                        final card = entry.value;
                        return Column(
                          children: [
                            _CardTile(card: card, ref: ref),
                            if (index < pm.cards.length - 1)
                              const Divider(height: 1, thickness: 1, color: Color(0xFFF5F0EB),
                                indent: AppConstants.paddingSM, endIndent: AppConstants.paddingSM),
                          ],
                        );
                      }),

                    // Divider before add button
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF5F0EB),
                      indent: AppConstants.paddingSM, endIndent: AppConstants.paddingSM),

                    // Add card button
                    SettingsTile(
                      icon: Icons.add_card_outlined,
                      label: 'Agregar tarjeta',
                      trailing: pm.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                      onTap: pm.isLoading ? null : () => ref.read(paymentMethodsProvider.notifier).addCard(),
                    ),
                  ],
                ),
              ),
            ],
          )),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Otros metodos ──
          _animated(1, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Otros metodos'),

              // Grouped card container for other methods
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  border: Border.all(color: ext.cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _OtherMethodTile(
                  icon: Icons.store_outlined,
                  iconColor: const Color(0xFFCC0000),
                  label: 'Pago en efectivo',
                  subtitle: 'OXXO, 7-Eleven, tiendas de conveniencia',
                  badgeText: 'Disponible',
                  badgeColor: Colors.green.shade600,
                  onTap: () => _showCashInfo(context),
                ),
              ),
            ],
          )),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Fee info ──
          _animated(2, Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(color: ext.cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outlined,
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
          )),

          const SizedBox(height: AppConstants.paddingXXL),
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
      icon: Icons.credit_card_outlined,
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
            child: Icon(Icons.delete_outlined, size: 18, color: Colors.red.shade400),
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
      await showShredderTransition(context);
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
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM,
          vertical: AppConstants.paddingSM + 4,
        ),
        child: Row(
          children: [
            // IconBox 34x34, radius 10, colored bg
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: AppConstants.iconSizeSM),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_outlined, size: 20,
                color: cs.onSurface.withValues(alpha: 0.3)),
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

// ---------------------------------------------------------------------------
// Gift card redemption tile (stateful: enter code → redeem → credits saldo)
// ---------------------------------------------------------------------------

class _GiftCardRedemptionTile extends ConsumerStatefulWidget {
  const _GiftCardRedemptionTile();

  @override
  ConsumerState<_GiftCardRedemptionTile> createState() =>
      _GiftCardRedemptionTileState();
}

class _GiftCardRedemptionTileState
    extends ConsumerState<_GiftCardRedemptionTile> {
  bool _expanded = false;
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ToastService.showError('Ingresa el codigo');
      return;
    }
    setState(() => _loading = true);
    try {
      final userId = SupabaseClientService.currentUserId;
      if (userId == null) {
        ToastService.showError('Debes iniciar sesion');
        return;
      }

      final data = await SupabaseClientService.client
          .from('gift_cards')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (data == null) {
        ToastService.showError('Codigo no encontrado');
        return;
      }

      final isActive = data['is_active'] as bool? ?? false;
      final redeemedAt = data['redeemed_at'] as String?;
      final expiresAt = data['expires_at'] as String?;
      final remaining = (data['remaining_amount'] as num?)?.toDouble() ?? 0;

      if (!isActive || redeemedAt != null) {
        ToastService.showError('Esta tarjeta ya fue canjeada');
        return;
      }
      if (expiresAt != null &&
          DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) == true) {
        ToastService.showError('Esta tarjeta ha vencido');
        return;
      }
      if (remaining <= 0) {
        ToastService.showError('Esta tarjeta no tiene saldo');
        return;
      }

      await SupabaseClientService.client.from('gift_cards').update({
        'redeemed_by': userId,
        'redeemed_at': DateTime.now().toUtc().toIso8601String(),
        'remaining_amount': 0,
        'is_active': false,
      }).eq('id', data['id'] as String);

      await SupabaseClientService.client.rpc(
        'increment_saldo',
        params: {'p_user_id': userId, 'p_amount': remaining},
      );

      _codeCtrl.clear();
      setState(() => _expanded = false);
      ref.invalidate(_saldoProvider);

      if (mounted) {
        ToastService.showSuccess(
            '\$${remaining.toStringAsFixed(2)} MXN acreditados a tu saldo');
      }
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(label: 'Tarjeta de regalo'),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                  color: colors.outline.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded,
                      color: Color(0xFFEC4899), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Canjear tarjeta de regalo',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                  color: colors.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingresa el codigo de tu tarjeta',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2),
                        decoration: InputDecoration(
                          hintText: 'XXXXXXXX',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 16,
                              letterSpacing: 2,
                              color: colors.onSurface.withValues(alpha: 0.3)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _redeem,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEC4899),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Canjear',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
