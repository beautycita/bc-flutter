import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/cinematic_question_text.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  bool _isConfirming = false;

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
            _TransportCard(result: result, isBooked: isBooked, uberScheduled: state.uberScheduled),
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
              // Success actions -- gold gradient button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  notifier.reset();
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
                    'LISTO',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: const Color(0xFF1A1400),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Confirm button -- gold gradient
              GestureDetector(
                onTap: _isConfirming
                    ? null
                    : () async {
                        setState(() => _isConfirming = true);
                        try {
                          HapticFeedback.mediumImpact();
                          await notifier.confirmBooking();
                        } finally {
                          if (mounted) setState(() => _isConfirming = false);
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
                          result.transport.mode == 'uber'
                              ? 'CONFIRMAR TODO'
                              : 'CONFIRMAR RESERVA',
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
        subtitle = 'Ve a tu OXXO mas cercano para completar el pago';
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
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 3),
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
// Transport card
// ---------------------------------------------------------------------------

class _TransportCard extends StatelessWidget {
  final ResultCard result;
  final bool isBooked;
  final bool uberScheduled;

  const _TransportCard({
    required this.result,
    this.isBooked = false,
    this.uberScheduled = false,
  });

  IconData _icon(String mode) {
    switch (mode) {
      case 'car':
        return Icons.directions_car;
      case 'uber':
        return Icons.local_taxi;
      case 'transit':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'car':
        return 'En auto';
      case 'uber':
        return 'Transporte Uber';
      case 'transit':
        return 'Transporte';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final t = result.transport;
    final isUber = t.mode == 'uber';

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
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(_icon(t.mode),
                    color: palette.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  _modeLabel(t.mode),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.onSurface,
                  ),
                ),
              ],
            ),

            if (isUber) ...[
              const SizedBox(height: AppConstants.paddingMD),

              // Uber status badge (after booking)
              if (isBooked) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: uberScheduled
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        uberScheduled
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 16,
                        color: uberScheduled
                            ? const Color(0xFF4CAF50)
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        uberScheduled
                            ? 'Viajes programados'
                            : 'Vincula Uber para programar viajes',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: uberScheduled
                              ? const Color(0xFF4CAF50)
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
              ],

              // Outbound leg
              _UberLegRow(
                label: 'Ida',
                icon: Icons.arrow_forward,
                destination: result.business.name,
                pickupTime: _formatPickupTime(
                    result.slot.startTime, t.durationMin, 3),
                fareMin: t.uberEstimateMin,
                fareMax: t.uberEstimateMax,
                durationMin: t.durationMin,
                distanceKm: t.distanceKm,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),

              // Return leg
              _UberLegRow(
                label: 'Vuelta',
                icon: Icons.arrow_back_rounded,
                destination: 'Tu ubicacion',
                pickupTime: _formatReturnPickupTime(
                  result.slot.startTime,
                  result.service.durationMinutes,
                ),
                fareMin: t.uberEstimateMin,
                fareMax: t.uberEstimateMax,
                durationMin: t.durationMin,
                distanceKm: t.distanceKm,
              ),
            ] else ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  '${t.durationMin} min · ${t.distanceKm.toStringAsFixed(1)} km',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: palette.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (t.mode == 'transit' && t.transitSummary != null)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 2),
                  child: Text(
                    t.transitSummary!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: palette.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPickupTime(DateTime appointmentTime, int driveMin, int buffer) {
    final pickup =
        appointmentTime.subtract(Duration(minutes: driveMin + buffer));
    return DateFormat('h:mm a').format(pickup);
  }

  String _formatReturnPickupTime(DateTime appointmentTime, int durationMin) {
    final pickup =
        appointmentTime.add(Duration(minutes: durationMin + 5));
    return '~${DateFormat('h:mm a').format(pickup)}';
  }
}

// ---------------------------------------------------------------------------
// Uber leg row
// ---------------------------------------------------------------------------

class _UberLegRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String destination;
  final String pickupTime;
  final double? fareMin;
  final double? fareMax;
  final int durationMin;
  final double distanceKm;

  const _UberLegRow({
    required this.label,
    required this.icon,
    required this.destination,
    required this.pickupTime,
    this.fareMin,
    this.fareMax,
    required this.durationMin,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final hasFare = fareMin != null && fareMax != null;

    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 16, color: palette.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destination,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: palette.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.access_time,
                  size: 16, color: palette.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'Recogida: $pickupTime',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: palette.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$durationMin min · ${distanceKm.toStringAsFixed(1)} km',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: palette.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.attach_money,
                  size: 16,
                  color: hasFare
                      ? palette.primary
                      : palette.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                hasFare
                    ? '~\$${fareMin!.toStringAsFixed(0)}-\$${fareMax!.toStringAsFixed(0)} MXN'
                    : '~\$${_estimateFare(distanceKm, durationMin)} MXN',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasFare
                      ? palette.primary
                      : palette.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Simple fare estimate based on Uber MX rates when API estimate unavailable.
  /// Base ~28 MXN + ~5 MXN/km + ~1.5 MXN/min.
  static String _estimateFare(double km, int min) {
    final low = (28 + km * 4.5 + min * 1.2).round();
    final high = (35 + km * 6.0 + min * 1.8).round();
    return '\$$low-\$$high';
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
    final t = result.transport;
    final servicePrice = result.service.price;
    final currency = result.service.currency;
    final isUber = t.mode == 'uber';

    // Use API estimates if available, otherwise compute local estimate
    double uberLow;
    double uberHigh;
    if (t.uberEstimateMin != null && t.uberEstimateMax != null) {
      uberLow = t.uberEstimateMin!;
      uberHigh = t.uberEstimateMax!;
    } else {
      uberLow = 28 + t.distanceKm * 4.5 + t.durationMin * 1.2;
      uberHigh = 35 + t.distanceKm * 6.0 + t.durationMin * 1.8;
    }

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
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 3),
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
            if (isUber) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: palette.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Uber cobra por separado: ~\$${(uberLow * 2).toStringAsFixed(0)}-\$${(uberHigh * 2).toStringAsFixed(0)} $currency ida y vuelta',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: palette.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment method selector
// ---------------------------------------------------------------------------

class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _PaymentMethodSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PaymentMethodCard(
          icon: Icons.credit_card,
          label: 'Tarjeta',
          subtitle: 'Pago inmediato',
          method: 'card',
          isSelected: selected == 'card',
          onTap: () => onSelect('card'),
        ),
        const SizedBox(width: 10),
        _PaymentMethodCard(
          icon: Icons.store,
          label: 'OXXO',
          subtitle: 'Paga en tienda',
          method: 'oxxo',
          isSelected: selected == 'oxxo',
          onTap: () => onSelect('oxxo'),
        ),
        const SizedBox(width: 10),
        _PaymentMethodCard(
          icon: Icons.currency_bitcoin,
          label: 'Bitcoin',
          subtitle: 'Pago con crypto',
          method: 'bitcoin',
          isSelected: selected == 'bitcoin',
          onTap: () => onSelect('bitcoin'),
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
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: ext.goldGradientDirectional(),
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            boxShadow: isSelected
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
              color: isSelected ? const Color(0xFFFFF8DC) : Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD - 2),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? const Color(0xFFB8860B)
                      : palette.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
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
                    color: isSelected
                        ? const Color(0xFFA67C00)
                        : palette.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
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
