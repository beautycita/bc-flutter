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
import '../providers/btc_wallet_provider.dart';
import '../providers/payment_methods_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/cinematic_question_text.dart';
import '../widgets/phone_verify_gate_sheet.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  bool _isConfirming = false;

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
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

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
            _SummaryCard(result: result),
            const SizedBox(height: AppConstants.paddingMD),
            _PriceBreakdown(result: result),
            if (!isBooked) ...[
              const SizedBox(height: AppConstants.paddingMD),
              _PaymentMethodSelector(
                selected: state.paymentMethod,
                onSelect: (method) => notifier.selectPaymentMethod(method),
              ),
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
                    gradient: ext.goldGradientDirectional(),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                      color: const Color(0xFF1A1400),
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
              // Confirm button — gold gradient
              GestureDetector(
                onTap: _isConfirming ? null : _handleConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    gradient: ext.goldGradientDirectional(),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isConfirming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'CONFIRMAR RESERVA',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFF1A1400),
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
    final isPending = paymentMethod == 'oxxo' || paymentMethod == 'bitcoin';

    String subtitle;
    switch (paymentMethod) {
      case 'oxxo':
        subtitle = 'Acude a OXXO o 7-Eleven para completar el pago';
      case 'bitcoin':
        subtitle = 'Completa el pago en Bitcoin para confirmar';
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
    final dateStr = formatter.format(result.slot.startTime);
    final capitalizedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Container(
      decoration: BoxDecoration(
        gradient: ext.goldGradientDirectional(),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 1.5),
        ),
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
                    '${result.service.name} — ${result.staff.name}',
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
    final servicePrice = result.service.price;
    final currency = result.service.currency;

    return Container(
      decoration: BoxDecoration(
        gradient: ext.goldGradientDirectional(),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 1.5),
        ),
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

class _PaymentMethodSelector extends ConsumerStatefulWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _PaymentMethodSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  ConsumerState<_PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends ConsumerState<_PaymentMethodSelector> {
  bool _didAutoSelect = false;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(paymentMethodsProvider).cards;
    final btcWallet = ref.watch(btcWalletProvider);
    final hasCards = cards.isNotEmpty;
    final btcEnabled = btcWallet.totpEnabled;

    // Smart preselection: card if user has saved cards, otherwise cash
    if (!_didAutoSelect) {
      _didAutoSelect = true;
      final preferred = hasCards ? 'card' : 'oxxo';
      if (widget.selected != preferred) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSelect(preferred);
        });
      }
    }

    return Row(
      children: [
        _PaymentMethodCard(
          icon: Icons.credit_card,
          label: 'Tarjeta',
          subtitle: 'Pago inmediato',
          method: 'card',
          isSelected: widget.selected == 'card',
          onTap: () => widget.onSelect('card'),
        ),
        const SizedBox(width: 10),
        _PaymentMethodCard(
          icon: Icons.store,
          label: 'Efectivo',
          subtitle: 'OXXO, 7-Eleven',
          method: 'oxxo',
          isSelected: widget.selected == 'oxxo',
          onTap: () => widget.onSelect('oxxo'),
        ),
        const SizedBox(width: 10),
        _PaymentMethodCard(
          icon: Icons.currency_bitcoin,
          label: 'Bitcoin',
          subtitle: btcEnabled ? 'Pago con crypto' : 'Configura wallet',
          method: 'bitcoin',
          isSelected: widget.selected == 'bitcoin',
          enabled: btcEnabled,
          onTap: btcEnabled ? () => widget.onSelect('bitcoin') : null,
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String method;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.method,
    required this.isSelected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final disabled = !enabled;

    return Expanded(
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap?.call();
              },
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: ext.goldGradientDirectional(),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: isSelected && !disabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected && !disabled ? const Color(0xFFFFF8DC) : Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD - 2),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: isSelected && !disabled
                        ? const Color(0xFFB8860B)
                        : palette.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected && !disabled
                          ? const Color(0xFF8B6914)
                          : palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: isSelected && !disabled
                          ? const Color(0xFFA67C00)
                          : palette.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
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
