import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/cinematic_question_text.dart';

/// 13-stop real gold gradient for card borders and buttons.
const _goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF8B6914),
    Color(0xFFD4AF37),
    Color(0xFFFFF8DC),
    Color(0xFFFFD700),
    Color(0xFFC19A26),
    Color(0xFFF5D547),
    Color(0xFFFFFFE0),
    Color(0xFFD4AF37),
    Color(0xFFA67C00),
    Color(0xFFCDAD38),
    Color(0xFFFFF8DC),
    Color(0xFFB8860B),
    Color(0xFF8B6914),
  ],
  stops: [0.0, 0.08, 0.15, 0.25, 0.35, 0.45, 0.50, 0.58, 0.68, 0.78, 0.85, 0.93, 1.0],
);

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

    if (result == null) {
      return const Scaffold(body: Center(child: Text('Sin seleccion')));
    }

    final isBooked = state.step == BookingFlowStep.booked;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.surfaceCream,
        elevation: 0,
        leading: isBooked
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: BeautyCitaTheme.textDark, size: 24),
                onPressed: () => notifier.goBack(),
              ),
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        child: Column(
          children: [
            if (isBooked) ...[
              const _SuccessBanner(),
              const SizedBox(height: BeautyCitaTheme.spaceMD),
            ] else ...[
              const CinematicQuestionText(
                text: 'Confirma tu cita',
                fontSize: 24,
                accentColor: BeautyCitaTheme.secondaryGold,
              ),
              const SizedBox(height: BeautyCitaTheme.spaceMD),
            ],
            _SummaryCard(result: result),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            _TransportCard(result: result, isBooked: isBooked, uberScheduled: state.uberScheduled),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            _PriceBreakdown(result: result),
            const SizedBox(height: BeautyCitaTheme.spaceXL),
            if (isBooked) ...[
              // Success actions — gold gradient button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  notifier.reset();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: BeautyCitaTheme.spaceMD),
                  decoration: BoxDecoration(
                    gradient: _goldGradient,
                    borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
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
              // Confirm button — gold gradient
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
                  padding: const EdgeInsets.symmetric(vertical: BeautyCitaTheme.spaceMD),
                  decoration: BoxDecoration(
                    gradient: _goldGradient,
                    borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
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
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: BeautyCitaTheme.secondaryGold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: BeautyCitaTheme.secondaryGold,
            size: 48,
          ),
        ),
        const SizedBox(height: BeautyCitaTheme.spaceMD),
        Text(
          'Cita reservada',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: BeautyCitaTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Te enviamos la confirmacion',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: BeautyCitaTheme.textLight,
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
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final dateStr = formatter.format(result.slot.startTime);
    final capitalizedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Container(
      decoration: BoxDecoration(
        gradient: _goldGradient,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
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
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium - 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business name
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: BeautyCitaTheme.primaryRose, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.business.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: BeautyCitaTheme.textDark,
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
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
              ),
            ],
            const SizedBox(height: BeautyCitaTheme.spaceMD),

            // Service + staff
            Row(
              children: [
                const Icon(Icons.content_cut,
                    color: BeautyCitaTheme.primaryRose, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.service.name} — ${result.staff.name}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: BeautyCitaTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeautyCitaTheme.spaceSM),

            // Date/time
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: BeautyCitaTheme.primaryRose, size: 20),
                const SizedBox(width: 8),
                Text(
                  capitalizedDate,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeautyCitaTheme.spaceXS),

            // Duration
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                '${result.service.durationMinutes} min',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: BeautyCitaTheme.textLight,
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
    final t = result.transport;
    final isUber = t.mode == 'uber';
    final hasEstimate = t.uberEstimateMin != null && t.uberEstimateMax != null;

    return Container(
      decoration: BoxDecoration(
        gradient: _goldGradient,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
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
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium - 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(_icon(t.mode),
                    color: BeautyCitaTheme.primaryRose, size: 24),
                const SizedBox(width: 12),
                Text(
                  _modeLabel(t.mode),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ],
            ),

            if (isUber) ...[
              const SizedBox(height: BeautyCitaTheme.spaceMD),

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
                const SizedBox(height: BeautyCitaTheme.spaceSM),
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
                    color: BeautyCitaTheme.textLight,
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
                      color: BeautyCitaTheme.textLight,
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
              color: BeautyCitaTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 16, color: BeautyCitaTheme.textLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destination,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 16, color: BeautyCitaTheme.textLight),
              const SizedBox(width: 6),
              Text(
                'Recogida: $pickupTime',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${durationMin} min · ${distanceKm.toStringAsFixed(1)} km',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: BeautyCitaTheme.textLight.withValues(alpha: 0.7),
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
                      ? BeautyCitaTheme.primaryRose
                      : BeautyCitaTheme.textLight),
              const SizedBox(width: 6),
              Text(
                hasFare
                    ? '~\$${fareMin!.toStringAsFixed(0)}-\$${fareMax!.toStringAsFixed(0)} MXN'
                    : '~\$${_estimateFare(distanceKm, durationMin)} MXN',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasFare
                      ? BeautyCitaTheme.primaryRose
                      : BeautyCitaTheme.textLight,
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
        gradient: _goldGradient,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
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
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium - 3),
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
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
                Text(
                  '\$${servicePrice.toStringAsFixed(0)} $currency',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BeautyCitaTheme.primaryRose,
                  ),
                ),
              ],
            ),
            if (isUber) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: BeautyCitaTheme.textLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Uber cobra por separado: ~\$${(uberLow * 2).toStringAsFixed(0)}-\$${(uberHigh * 2).toStringAsFixed(0)} $currency ida y vuelta',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: BeautyCitaTheme.textLight,
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

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: BeautyCitaTheme.textLight,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: BeautyCitaTheme.textDark,
          ),
        ),
      ],
    );
  }
}
