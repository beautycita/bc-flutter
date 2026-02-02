import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/cinematic_question_text.dart';

class ConfirmationScreen extends ConsumerWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);
    final notifier = ref.read(bookingFlowProvider.notifier);
    final result = state.selectedResult;

    if (result == null) {
      return const Scaffold(body: Center(child: Text('Sin selección')));
    }

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.surfaceCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: BeautyCitaTheme.textDark),
          onPressed: () => notifier.goBack(),
        ),
        title: const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        child: Column(
          children: [
            const CinematicQuestionText(
              text: 'Confirma tu cita',
              fontSize: 24,
              accentColor: BeautyCitaTheme.secondaryGold,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            _SummaryCard(result: result),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            _TransportCard(result: result),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            _PriceBreakdown(result: result),
            const SizedBox(height: BeautyCitaTheme.spaceXL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  debugPrint(
                      'TODO: Create booking for ${result.business.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeautyCitaTheme.primaryRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: BeautyCitaTheme.spaceMD),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BeautyCitaTheme.radiusLarge),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  result.transport.mode == 'uber'
                      ? 'CONFIRMAR TODO'
                      : 'CONFIRMAR RESERVA',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ResultCard result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final dateStr = formatter.format(result.slot.startTime);
    final capitalizedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
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

class _TransportCard extends StatelessWidget {
  final ResultCard result;

  const _TransportCard({required this.result});

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

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
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

            if (isUber && hasEstimate) ...[
              const SizedBox(height: BeautyCitaTheme.spaceMD),

              // Outbound leg
              _UberLegRow(
                label: 'Ida',
                icon: Icons.arrow_forward,
                destination: result.business.name,
                pickupTime: _formatPickupTime(
                    result.slot.startTime, t.durationMin, 3),
                fareMin: t.uberEstimateMin!,
                fareMax: t.uberEstimateMax!,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),

              // Return leg
              _UberLegRow(
                label: 'Vuelta',
                icon: Icons.arrow_back,
                destination: 'Tu ubicación',
                pickupTime: _formatReturnPickupTime(
                  result.slot.startTime,
                  result.service.durationMinutes,
                ),
                fareMin: t.uberEstimateMin!,
                fareMax: t.uberEstimateMax!,
              ),

              const SizedBox(height: BeautyCitaTheme.spaceMD),

              // Return destination change button
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Open destination picker
                  debugPrint('Change return destination');
                },
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(
                  '¿Volver a otra dirección?',
                  style: GoogleFonts.nunito(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BeautyCitaTheme.primaryRose,
                  side: BorderSide(
                    color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                  ),
                ),
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

class _UberLegRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String destination;
  final String pickupTime;
  final double fareMin;
  final double fareMax;

  const _UberLegRow({
    required this.label,
    required this.icon,
    required this.destination,
    required this.pickupTime,
    required this.fareMin,
    required this.fareMax,
  });

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.attach_money,
                  size: 16, color: BeautyCitaTheme.textLight),
              const SizedBox(width: 6),
              Text(
                '~\$${fareMin.toStringAsFixed(0)}-\$${fareMax.toStringAsFixed(0)} MXN',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  final ResultCard result;

  const _PriceBreakdown({required this.result});

  @override
  Widget build(BuildContext context) {
    final t = result.transport;
    final servicePrice = result.service.price;
    final currency = result.service.currency;
    final hasUber = t.mode == 'uber' &&
        t.uberEstimateMin != null &&
        t.uberEstimateMax != null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        child: Column(
          children: [
            _PriceRow(
              label: 'Servicio',
              value: '\$${servicePrice.toStringAsFixed(0)} $currency',
            ),
            if (hasUber) ...[
              const SizedBox(height: 8),
              _PriceRow(
                label: 'Uber (est.)',
                value:
                    '~\$${(t.uberEstimateMin! * 2).toStringAsFixed(0)}-${(t.uberEstimateMax! * 2).toStringAsFixed(0)} $currency',
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasUber ? 'Total estimado' : 'Total',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
                Text(
                  hasUber
                      ? '~\$${(servicePrice + t.uberEstimateMin! * 2).toStringAsFixed(0)}-${(servicePrice + t.uberEstimateMax! * 2).toStringAsFixed(0)} $currency'
                      : '\$${servicePrice.toStringAsFixed(0)} $currency',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BeautyCitaTheme.primaryRose,
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
