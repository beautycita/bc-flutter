import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/user_preferences_provider.dart';
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
    final defaultTransport = ref.watch(userPrefsProvider).defaultTransport;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: BeautyCitaTheme.textDark,
            size: 24,
          ),
          onPressed: () => bookingNotifier.goBack(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top content area — question + context
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BeautyCitaTheme.primaryRose,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CinematicQuestionText(
                    text: 'Como llegas a tu cita?',
                    fontSize: 26,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom interactive area — thumb reach zone
            if (_locationLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: BeautyCitaTheme.primaryRose,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Obteniendo tu ubicacion...',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: BeautyCitaTheme.textLight,
                      ),
                    ),
                  ],
                ),
              )
            else if (_locationFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
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
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Row(
                  children: [
                    Expanded(
                      child: _TransportCard(
                        emoji: '\u{1F697}',
                        label: 'Mi auto',
                        subtitle: 'Manejo yo',
                        isDefault: defaultTransport == 'car',
                        onTap: () => _selectTransport('car'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TransportCard(
                        emoji: '\u{1F695}',
                        label: 'Uber',
                        subtitle: 'Que me lleven',
                        isDefault: defaultTransport == 'uber',
                        onTap: () => _selectTransport('uber'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TransportCard(
                        emoji: '\u{1F68C}',
                        label: 'Transporte',
                        subtitle: 'Me llevo yo',
                        isDefault: defaultTransport == 'transit',
                        onTap: () => _selectTransport('transit'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransportCard extends StatefulWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final bool isDefault;
  final VoidCallback onTap;

  const _TransportCard({
    required this.emoji,
    required this.label,
    required this.subtitle,
    this.isDefault = false,
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
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0, _isPressed ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        decoration: BoxDecoration(
          color: _isPressed
              ? BeautyCitaTheme.surfaceCream
              : widget.isDefault
                  ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.04)
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isPressed
                ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.3)
                : widget.isDefault
                    ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.4)
                    : BeautyCitaTheme.dividerLight,
            width: 1,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 28, height: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: BeautyCitaTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
