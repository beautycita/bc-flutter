import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/payment_methods_provider.dart';
import '../providers/profile_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../services/supabase_client.dart';
import '../widgets/cinematic_question_text.dart';
import '../widgets/phone_verify_gate_sheet.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  bool _isConfirming = false;
  late final AnimationController _cascadeController;

  @override
  void initState() {
    super.initState();
    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void dispose() {
    _cascadeController.dispose();
    super.dispose();
  }

  /// "Breath in" cascade: each element starts at scale 0.98 / opacity 0,
  /// expands to 1.0 while fading in. 80ms stagger between elements.
  Widget _cascadeElement(int index, Widget child) {
    final startFraction = (index * 80) / 620;
    final endFraction = (startFraction + 300 / 620).clamp(0.0, 1.0);

    final curved = CurvedAnimation(
      parent: _cascadeController,
      curve: Interval(startFraction, endFraction, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        final scale = 0.98 + 0.02 * t;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _handleConfirm() async {
    final notifier = ref.read(bookingFlowProvider.notifier);
    final profile = ref.read(profileProvider);

    // Phone verification gate
    if (!profile.hasVerifiedPhone) {
      final verified = await showPhoneVerifyGate(context);
      if (!verified || !mounted) return;
    }

    setState(() => _isConfirming = true);
    try {
      HapticFeedback.mediumImpact();
      await notifier.confirmBooking();
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingFlowProvider);
    final notifier = ref.read(bookingFlowProvider.notifier);
    final result = state.selectedResult;
    final palette = Theme.of(context).colorScheme;

    if (result == null) {
      return const Scaffold(body: Center(child: Text('Sin seleccion')));
    }

    final isBooked = state.step == BookingFlowStep.booked;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: isBooked
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: palette.onSurface, size: 24),
                onPressed: () => notifier.goBack(),
              ),
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          children: [
            if (isBooked) ...[
              _SuccessBanner(paymentMethod: state.paymentMethod),
              const SizedBox(height: AppConstants.paddingMD),
            ] else ...[
              CinematicQuestionText(
                text: 'Confirma tu cita',
                fontSize: 24,
                accentColor: palette.secondary,
              ),
              const SizedBox(height: AppConstants.paddingMD),
            ],
            _cascadeElement(0, _SummaryCard(result: result)),
            const SizedBox(height: AppConstants.paddingMD),
            _cascadeElement(1, _PriceBreakdown(result: result)),
            if (!isBooked) ...[
              const SizedBox(height: AppConstants.paddingMD),
              _cascadeElement(2, _PaymentMethodSelector(
                selected: state.paymentMethod,
                onSelect: (method) => notifier.selectPaymentMethod(method),
                servicePrice: result.service.price ?? 0,
                businessId: result.business.id,
              )),
            ],
            const SizedBox(height: AppConstants.paddingXL),
            if (isBooked) ...[
              // "VER COMO LLEGAR" — navigates to appointment detail with map
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (state.bookingId != null) {
                    context.push('/appointment/${state.bookingId}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'VER COMO LLEGAR',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              // Secondary "Listo" option
              GestureDetector(
                onTap: () {
                  notifier.reset();
                },
                child: Text(
                  'Listo',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: palette.onSurface.withValues(alpha: 0.5),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ] else ...[
              // Confirm button — brand gradient
              GestureDetector(
                onTap: _isConfirming ? null : _handleConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isConfirming
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          'CONFIRMAR RESERVA',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success banner (shown after booking)
// ---------------------------------------------------------------------------

class _SuccessBanner extends StatelessWidget {
  final String paymentMethod;

  const _SuccessBanner({required this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final isPending = paymentMethod == 'oxxo';

    String subtitle;
    switch (paymentMethod) {
      case 'oxxo':
        subtitle = 'Acude a OXXO o 7-Eleven para completar el pago';
      default:
        subtitle = 'Te enviamos la confirmacion';
    }

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isPending
                ? Colors.orange.withValues(alpha: 0.12)
                : palette.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPending ? Icons.schedule_rounded : Icons.check_circle_rounded,
            color: isPending ? Colors.orange : palette.secondary,
            size: 48,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),
        Text(
          isPending ? 'Pago pendiente' : 'Cita reservada',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: palette.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: isPending ? Colors.orange.shade700 : palette.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final ResultCard result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final dateStr = formatter.format(result.slot!.startTime);
    final capitalizedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business name
            Row(
              children: [
                Icon(Icons.location_on,
                    color: palette.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.business.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (result.business.address != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  result.business.address!,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: palette.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppConstants.paddingMD),

            // Service + staff
            Row(
              children: [
                Icon(Icons.content_cut,
                    color: palette.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.service.name} — ${result.staff?.name ?? ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: palette.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // Date/time
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: palette.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  capitalizedDate,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: palette.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingXS),

            // Duration
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                '${result.service.durationMinutes} min',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: palette.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price breakdown
// ---------------------------------------------------------------------------

class _PriceBreakdown extends StatelessWidget {
  final ResultCard result;

  const _PriceBreakdown({required this.result});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final servicePrice = result.service.price ?? 0;
    final currency = result.service.currency;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          children: [
            _PriceRow(
              label: 'Servicio',
              value: '\$${servicePrice.toStringAsFixed(0)} $currency',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.onSurface,
                  ),
                ),
                Text(
                  '\$${servicePrice.toStringAsFixed(0)} $currency',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment method selector
// ---------------------------------------------------------------------------

class _BizPaymentPolicy {
  final bool stripeEnabled;
  final bool depositRequired;
  final double depositPercentage;
  const _BizPaymentPolicy({
    required this.stripeEnabled,
    required this.depositRequired,
    required this.depositPercentage,
  });

  bool get stripeBlocked => !stripeEnabled;
  double depositFor(double price) =>
      depositRequired ? (price * depositPercentage).clamp(0, price) : 0;
}

/// Payment policy for a salon: Stripe availability + deposit requirements.
/// Used by the payment selector to decide which tiles to show and whether
/// "En salon" requires a saldo-based deposit first.
final _bizPaymentPolicyProvider =
    FutureProvider.family<_BizPaymentPolicy, String>((ref, businessId) async {
  if (businessId.isEmpty) {
    return const _BizPaymentPolicy(
      stripeEnabled: false,
      depositRequired: false,
      depositPercentage: 0,
    );
  }
  final data = await SupabaseClientService.client
      .from(BCTables.businesses)
      .select('stripe_charges_enabled, deposit_required, deposit_percentage')
      .eq('id', businessId)
      .maybeSingle();
  if (data == null) {
    return const _BizPaymentPolicy(
      stripeEnabled: false,
      depositRequired: false,
      depositPercentage: 0,
    );
  }
  return _BizPaymentPolicy(
    stripeEnabled: data['stripe_charges_enabled'] as bool? ?? false,
    depositRequired: data['deposit_required'] as bool? ?? false,
    // deposit_percentage is stored as 0..1 (e.g. 0.20 for 20%)
    depositPercentage: (data['deposit_percentage'] as num?)?.toDouble() ?? 0,
  );
});

final _userSaldoProvider = FutureProvider<double>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return 0;
  final data = await SupabaseClientService.client
      .from(BCTables.profiles)
      .select('saldo')
      .eq('id', userId)
      .maybeSingle();
  return (data?['saldo'] as num?)?.toDouble() ?? 0;
});

class _PaymentMethodSelector extends ConsumerStatefulWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final double servicePrice;
  final String businessId;

  const _PaymentMethodSelector({
    required this.selected,
    required this.onSelect,
    required this.servicePrice,
    required this.businessId,
  });

  @override
  ConsumerState<_PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends ConsumerState<_PaymentMethodSelector> {
  bool _didAutoSelect = false;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(paymentMethodsProvider).cards;
    final hasCards = cards.isNotEmpty;

    final policyAsync = ref.watch(_bizPaymentPolicyProvider(widget.businessId));
    final policy = policyAsync.valueOrNull ??
        const _BizPaymentPolicy(
          stripeEnabled: false,
          depositRequired: false,
          depositPercentage: 0,
        );
    final stripeBlocked = policy.stripeBlocked;
    final depositAmount = policy.depositFor(widget.servicePrice);
    final hasDeposit = depositAmount > 0;

    // Saldo is applied automatically — not a choice
    final saldoAsync = ref.watch(_userSaldoProvider);
    final saldo = saldoAsync.valueOrNull ?? 0.0;
    final servicePrice = widget.servicePrice;
    final coversFullPrice = saldo >= servicePrice && servicePrice > 0;

    // Auto-pick the best default method once per mount. Priority:
    // saldo-covers-full > stripeBlocked fallback > card > oxxo.
    // Customer can always switch to "En salon" manually afterwards.
    if (!_didAutoSelect) {
      _didAutoSelect = true;
      String preferred;
      if (coversFullPrice) {
        preferred = 'saldo';
      } else if (stripeBlocked) {
        preferred = saldo > 0 ? 'saldo' : 'cash_direct';
      } else {
        preferred = hasCards ? 'card' : 'oxxo';
      }
      if (widget.selected != preferred) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSelect(preferred);
        });
      }
    }

    final remaining = coversFullPrice ? 0.0 : (servicePrice - saldo);

    return Column(
      children: [
        // Saldo applied automatically — show info banner, not a selectable option
        if (saldo > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 20, color: Color(0xFF059669)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coversFullPrice
                            ? 'Saldo aplicado: \$${servicePrice.toStringAsFixed(0)} MXN'
                            : 'Saldo aplicado: \$${saldo.toStringAsFixed(0)} MXN',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                      ),
                      if (!coversFullPrice)
                        Text(
                          'Resta: \$${remaining.toStringAsFixed(0)} MXN por cobrar',
                          style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF059669).withValues(alpha: 0.7)),
                        ),
                      if (coversFullPrice)
                        Text(
                          'Cubre el total — no se cobra tarjeta',
                          style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF059669).withValues(alpha: 0.7)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Notice banner for Stripe-blocked salons (they only support cash /
        // saldo; card/oxxo tiles are hidden below).
        if (stripeBlocked && !coversFullPrice) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este salon aun no acepta pagos en linea. Paga directamente en el salon.',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Deposit banner: customer chose (or will choose) to pay at salon
        // but the salon requires a deposit that must come through BC.
        if (hasDeposit && !coversFullPrice && widget.selected == 'cash_with_deposit') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563eb).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, size: 20, color: Color(0xFF2563eb)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deposito: \$${depositAmount.toStringAsFixed(0)} MXN (saldo)',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563eb)),
                      ),
                      Text(
                        'Efectivo al llegar: \$${(widget.servicePrice - depositAmount).toStringAsFixed(0)} MXN',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: const Color(0xFF2563eb).withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!coversFullPrice) _paymentTiles(
          stripeBlocked: stripeBlocked,
          hasDeposit: hasDeposit,
          saldo: saldo,
          depositAmount: depositAmount,
        ),
      ],
    );
  }

  Widget _paymentTiles({
    required bool stripeBlocked,
    required bool hasDeposit,
    required double saldo,
    required double depositAmount,
  }) {
    // Build the set of tiles applicable to this salon + user.
    // Policy matrix:
    //   stripeBlocked=true                → saldo + "en salon" only
    //   stripeBlocked=false, hasDeposit=0 → tarjeta + oxxo + "en salon"
    //   hasDeposit>0                      → tarjeta + oxxo + "en salon w/ deposit"
    final tiles = <Widget>[];

    if (!stripeBlocked) {
      tiles.add(_PaymentMethodCard(
        icon: Icons.credit_card,
        label: 'Tarjeta',
        subtitle: 'Pago inmediato',
        method: 'card',
        isSelected: widget.selected == 'card',
        onTap: () => widget.onSelect('card'),
      ));
      tiles.add(const SizedBox(width: 10));
      tiles.add(_PaymentMethodCard(
        icon: Icons.store,
        label: 'OXXO',
        subtitle: 'Pagar en tienda',
        method: 'oxxo',
        isSelected: widget.selected == 'oxxo',
        onTap: () => widget.onSelect('oxxo'),
      ));
      tiles.add(const SizedBox(width: 10));
    }

    if (stripeBlocked && saldo > 0) {
      tiles.add(_PaymentMethodCard(
        icon: Icons.account_balance_wallet,
        label: 'Saldo',
        subtitle: '\$${saldo.toStringAsFixed(0)} disponible',
        method: 'saldo',
        isSelected: widget.selected == 'saldo',
        onTap: () => widget.onSelect('saldo'),
      ));
      tiles.add(const SizedBox(width: 10));
    }

    // "En salon" tile — always present, but the behavior changes with deposit.
    if (hasDeposit) {
      final canCoverDeposit = saldo >= depositAmount;
      tiles.add(_PaymentMethodCard(
        icon: Icons.payments_outlined,
        label: 'En salon',
        subtitle: canCoverDeposit
            ? 'Dep. \$${depositAmount.toStringAsFixed(0)} + efectivo'
            : 'Necesitas \$${depositAmount.toStringAsFixed(0)} saldo',
        method: 'cash_with_deposit',
        isSelected: widget.selected == 'cash_with_deposit',
        onTap: canCoverDeposit ? () => widget.onSelect('cash_with_deposit') : null,
      ));
    } else {
      tiles.add(_PaymentMethodCard(
        icon: Icons.payments_outlined,
        label: 'En salon',
        subtitle: 'Paga al llegar',
        method: 'cash_direct',
        isSelected: widget.selected == 'cash_direct',
        onTap: () => widget.onSelect('cash_direct'),
      ));
    }

    return Row(children: tiles);
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String method;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.method,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.08)
                    : palette.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(
                  color: isSelected ? palette.primary : palette.onSurface.withValues(alpha: 0.12),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: isSelected
                        ? palette.primary
                        : palette.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? palette.primary
                          : palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: isSelected
                          ? palette.primary
                          : palette.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
          ),
        ),
      );
  }
}



class _PriceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: palette.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: palette.onSurface,
          ),
        ),
      ],
    );
  }
}
