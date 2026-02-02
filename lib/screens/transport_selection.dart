import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../services/location_service.dart';
import '../widgets/cinematic_question_text.dart';

class TransportSelection extends ConsumerStatefulWidget {
  const TransportSelection({super.key});

  @override
  ConsumerState<TransportSelection> createState() =>
      _TransportSelectionState();
}

class _TransportSelectionState extends ConsumerState<TransportSelection> {
  LatLng? _userLocation;
  bool _locationLoading = true;
  bool _locationFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _userLocation = location;
      _locationLoading = false;
      _locationFailed = location == null;
    });
  }

  void _selectTransport(String mode) {
    if (_userLocation == null) return;
    ref.read(bookingFlowProvider.notifier).selectTransport(
          mode,
          _userLocation!,
        );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingFlowProvider);
    final bookingNotifier = ref.read(bookingFlowProvider.notifier);
    final serviceName = bookingState.serviceName ?? 'tu servicio';

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
              const CinematicQuestionText(
                text: 'Como llegas a tu cita?',
                fontSize: 26,
              ),
              const SizedBox(height: 8),
              Text(
                serviceName,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
              const SizedBox(height: 32),
              if (_locationLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: BeautyCitaTheme.primaryRose,
                        ),
                        SizedBox(height: 16),
                        Text('Obteniendo tu ubicacion...'),
                      ],
                    ),
                  ),
                )
              else if (_locationFailed)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_off_rounded,
                          size: 48,
                          color: BeautyCitaTheme.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No pudimos obtener tu ubicacion',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: BeautyCitaTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activa el GPS y permite el acceso a ubicacion',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: BeautyCitaTheme.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _locationLoading = true;
                              _locationFailed = false;
                            });
                            _fetchLocation();
                          },
                          icon: const Icon(Icons.refresh, size: 20),
                          label: Text(
                            'Reintentar',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BeautyCitaTheme.primaryRose,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                BeautyCitaTheme.radiusMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _TransportCard(
                          emoji: '\u{1F697}',
                          label: 'Voy en\nmi auto',
                          subtitle: 'Manejo yo',
                          onTap: () => _selectTransport('car'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TransportCard(
                          emoji: '\u{1F695}',
                          label: 'Pide un\nUber',
                          subtitle: 'Que me lleven',
                          onTap: () => _selectTransport('uber'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TransportCard(
                          emoji: '\u{1F68C}',
                          label: 'Me llevo\nyo',
                          subtitle: 'Transporte',
                          onTap: () => _selectTransport('transit'),
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
