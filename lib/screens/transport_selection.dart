import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../models/curate_result.dart';
import '../widgets/cinematic_question_text.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/location_service.dart';

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
    // Check for temporary search location override first
    final tempLocation = ref.read(tempSearchLocationProvider);
    if (tempLocation != null) {
      setState(() {
        _userLocation = LatLng(lat: tempLocation.lat, lng: tempLocation.lng);
        _locationLoading = false;
        _locationFailed = false;
      });
      return;
    }
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
    final bookingNotifier = ref.read(bookingFlowProvider.notifier);
    final defaultTransport = ref.watch(userPrefsProvider).defaultTransport;
    final palette = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Back arrow
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => bookingNotifier.goBack(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: palette.onSurface,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Gradient animated title
              const Center(
                child: CinematicQuestionText(
                  text: 'Como llegaras?',
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esto nos ayuda a calcular el tiempo de traslado',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: palette.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Transport cards
              if (_locationLoading)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: palette.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Obteniendo tu ubicacion...',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: palette.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_locationFailed)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        size: 48,
                        color: palette.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pudimos obtener tu ubicacion',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Activa el GPS y permite el acceso a ubicacion',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: palette.onSurface.withValues(alpha: 0.5),
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
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _TransportCard(
                      icon: Icons.directions_car_rounded,
                      iconColor: palette.primary,
                      iconBgColor: palette.primary.withValues(alpha: 0.1),
                      label: 'Mi auto',
                      subtitle: 'Manejo yo',
                      isRecommended: defaultTransport == 'car',
                      onTap: () => _selectTransport('car'),
                    ),
                    const SizedBox(height: 14),
                    _TransportCard(
                      icon: Icons.local_taxi_rounded,
                      iconColor: palette.secondary,
                      iconBgColor: palette.secondary.withValues(alpha: 0.1),
                      borderColor: palette.secondary,
                      label: 'Uber',
                      subtitle: 'Que me lleven',
                      isRecommended: defaultTransport == 'uber',
                      onTap: () => _selectTransport('uber'),
                    ),
                    const SizedBox(height: 14),
                    _TransportCard(
                      icon: Icons.directions_bus_rounded,
                      iconColor: BeautyCitaTheme.accentTeal,
                      iconBgColor: BeautyCitaTheme.accentTealLight,
                      label: 'Transporte publico',
                      subtitle: 'Me llevo yo',
                      isRecommended: defaultTransport == 'transit',
                      onTap: () => _selectTransport('transit'),
                    ),
                  ],
                ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color? borderColor;
  final String label;
  final String subtitle;
  final bool isRecommended;
  final VoidCallback onTap;

  const _TransportCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.borderColor,
    required this.label,
    required this.subtitle,
    this.isRecommended = false,
    required this.onTap,
  });

  @override
  State<_TransportCard> createState() => _TransportCardState();
}

class _TransportCardState extends State<_TransportCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

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
          // ignore: deprecated_member_use
          ..scale(_isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: ext.goldGradientDirectional(),
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: _isPressed
                ? widget.iconBgColor
                : Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLG - 3),
          ),
          child: Row(
          children: [
            // Colored circle icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),

            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: palette.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.iconBgColor,
                            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                          ),
                          child: Text(
                            'Recomendado',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.iconColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: palette.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: palette.onSurface.withValues(alpha: 0.25),
              size: 24,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
