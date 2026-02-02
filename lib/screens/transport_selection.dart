import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';

class TransportSelection extends ConsumerWidget {
  const TransportSelection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingFlowProvider);
    final bookingNotifier = ref.read(bookingFlowProvider.notifier);

    final serviceName = bookingState.serviceName ?? 'tu servicio';

    // Hardcoded location placeholder (Guadalajara centro)
    const userLocation = LatLng(lat: 20.6736, lng: -103.3445);

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: BeautyCitaTheme.textDark,
          ),
          onPressed: () => bookingNotifier.goBack(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Como llegas?',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: BeautyCitaTheme.textDark,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para tu cita de $serviceName',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TransportCard(
                        emoji: '\u{1F697}', // car
                        label: 'Voy en\nmi auto',
                        subtitle: 'Manejo yo',
                        onTap: () => bookingNotifier.selectTransport(
                          'car',
                          userLocation,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TransportCard(
                        emoji: '\u{1F695}', // taxi
                        label: 'Pide un\nUber',
                        subtitle: 'Que me lleven',
                        onTap: () => bookingNotifier.selectTransport(
                          'uber',
                          userLocation,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TransportCard(
                        emoji: '\u{1F68C}', // bus
                        label: 'Me llevo\nyo',
                        subtitle: 'Transporte',
                        onTap: () => bookingNotifier.selectTransport(
                          'transit',
                          userLocation,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportCard extends StatefulWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TransportCard({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_TransportCard> createState() => _TransportCardState();
}

class _TransportCardState extends State<_TransportCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 160),
        decoration: BoxDecoration(
          color: _isPressed ? BeautyCitaTheme.surfaceCream : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isPressed
                ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji icon — large and expressive
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 32, height: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
