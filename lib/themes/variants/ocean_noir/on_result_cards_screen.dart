import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../models/curate_result.dart';
import '../../../providers/booking_flow_provider.dart';
import '../../../widgets/location_picker_sheet.dart';
import '../../../screens/invite_salon_screen.dart'
    show DiscoveredSalon, nearbySalonsProvider;
import '../../../screens/time_override_sheet.dart';
import 'on_widgets.dart';

class ONResultCardsScreen extends ConsumerStatefulWidget {
  const ONResultCardsScreen({super.key});

  @override
  ConsumerState<ONResultCardsScreen> createState() =>
      _ONResultCardsScreenState();
}

class _ONResultCardsScreenState extends ConsumerState<ONResultCardsScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _totalCards = 0;
  Offset _dragOffset = Offset.zero;
  bool _isBooking = false;

  late AnimationController _dismissController;
  late Animation<Offset> _dismissAnimation;
  late Animation<double> _dismissOpacity;
  bool _isDismissing = false;
  int _dismissDirection = 1;

  late AnimationController _snapBackController;
  late Animation<Offset> _snapBackAnimation;

  // Scan-line sweep for RESERVAR button
  late AnimationController _scanController;

  static const double _dismissThreshold = 0.25;
  static const double _velocityThreshold = 800.0;
  static const double _maxRotation = 0.10;
  static const double _verticalDamping = 0.3;

  @override
  void initState() {
    super.initState();

    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            if (_totalCards > 0) {
              if (_dismissDirection > 0) {
                _currentIndex = (_currentIndex + 1) % _totalCards;
              } else {
                _currentIndex = (_currentIndex - 1 + _totalCards) % _totalCards;
              }
            }
            _dragOffset = Offset.zero;
            _isDismissing = false;
          });
          _dismissController.reset();
        }
      });

    _dismissAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _dismissController, curve: Curves.easeOut));

    _dismissOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: const Interval(0.5, 1.0)),
    );

    _snapBackController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..addListener(() {
        setState(() => _dragOffset = _snapBackAnimation.value);
      });

    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _snapBackController, curve: Curves.elasticOut));

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  double _dragProgress(double cardWidth) =>
      cardWidth > 0 ? (_dragOffset.dx.abs() / cardWidth).clamp(0.0, 1.5) : 0.0;

  void _onDragUpdate(DragUpdateDetails details, double cardWidth) {
    if (_isDismissing) return;
    _snapBackController.stop();
    setState(() {
      _dragOffset += Offset(details.delta.dx, details.delta.dy * _verticalDamping);
    });
  }

  void _onDragEnd(DragEndDetails details, double cardWidth) {
    if (_isDismissing) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final distanceThresholdMet = _dragOffset.dx.abs() > cardWidth * _dismissThreshold;
    final velocityThresholdMet = velocity.abs() > _velocityThreshold;
    if (distanceThresholdMet || velocityThresholdMet) {
      _dismissDirection = (_dragOffset.dx != 0 ? _dragOffset.dx : velocity) > 0 ? 1 : -1;
      _animateDismiss(cardWidth);
    } else {
      _animateSnapBack();
    }
  }

  void _animateDismiss(double cardWidth) {
    HapticFeedback.lightImpact();
    final flyOffX = _dismissDirection * (cardWidth * 1.5);
    final flyOffY = _dragOffset.dy * 0.5;
    _dismissAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(flyOffX, flyOffY),
    ).animate(CurvedAnimation(parent: _dismissController, curve: Curves.easeOut));
    _dismissOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: const Interval(0.4, 1.0)),
    );
    setState(() => _isDismissing = true);
    _dismissController.forward(from: 0);
  }

  void _animateSnapBack() {
    _snapBackAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _snapBackController, curve: Curves.elasticOut));
    _snapBackController.forward(from: 0);
  }

  String _formatBadge(String k) {
    switch (k) {
      case 'available_today': return 'DISPONIBLE HOY';
      case 'walk_in_ok': return 'SIN CITA';
      case 'new_on_platform': return 'NUEVO EN BEAUTYCITA';
      case 'instant_confirm': return 'CONFIRM. INSTANTANEA';
      default: return k.toUpperCase();
    }
  }

  String _formatTrafficLevel(String l) {
    switch (l) {
      case 'light': return 'TRAFICO LIGERO';
      case 'moderate': return 'TRAFICO MODERADO';
      case 'heavy': return 'TRAFICO PESADO';
      default: return l.toUpperCase();
    }
  }

  IconData _getTransportIcon(String mode) {
    switch (mode) {
      case 'car': return Icons.directions_car;
      case 'uber': return Icons.local_taxi;
      case 'transit': return Icons.directions_bus;
      default: return Icons.directions_car;
    }
  }

  String _formatTransportInfo(TransportInfo t) {
    if (t.mode == 'uber' && t.uberEstimateMin != null && t.uberEstimateMax != null) {
      final rMin = (t.uberEstimateMin! * 2).toStringAsFixed(0);
      final rMax = (t.uberEstimateMax! * 2).toStringAsFixed(0);
      return '${t.durationMin}MIN // EST \$$rMin-\$$rMax IDA Y VUELTA';
    } else if (t.mode == 'transit' && t.transitSummary != null) {
      return '${t.durationMin}MIN // ${t.transitSummary?.toUpperCase()}';
    }
    return '${t.durationMin}MIN // ${_formatTrafficLevel(t.trafficLevel)}';
  }

  void _showTimeOverride(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TimeOverrideSheet(
        onSelect: (window) {
          ref.read(bookingFlowProvider.notifier).overrideTime(window);
        },
      ),
    );
  }

  TextStyle _rajdhani({double? fontSize, FontWeight? fontWeight, Color? color, double? letterSpacing}) {
    return GoogleFonts.rajdhani(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle _sourceSans({double? fontSize, FontWeight? fontWeight, Color? color}) {
    return GoogleFonts.sourceSans3(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingFlowProvider);
    final bookingNotifier = ref.read(bookingFlowProvider.notifier);
    final colors = ONColors.of(context);

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      return _ONNoResults(
        hasOverride: bookingState.overrideWindow != null,
        userLocation: bookingState.userLocation,
        serviceType: bookingState.serviceType,
        serviceName: bookingState.serviceName,
        onGoBack: () => bookingNotifier.goBack(),
        onClearOverride: () => bookingNotifier.clearOverride(),
      );
    }

    final results = bookingState.curateResponse!.results;
    final serviceName = (bookingState.serviceName ?? 'servicio').toUpperCase();
    _totalCards = results.length;
    if (_currentIndex >= _totalCards) _currentIndex = 0;

    return Scaffold(
      backgroundColor: colors.surface0,
      appBar: AppBar(
        backgroundColor: colors.surface0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.cyan, size: 22),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: Text(
          serviceName,
          style: _rajdhani(
            fontWeight: FontWeight.w700,
            color: colors.cyan,
            fontSize: 16,
            letterSpacing: 2.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.cyan.withValues(alpha: 0.0),
                  colors.cyan.withValues(alpha: 0.5),
                  colors.cyan.withValues(alpha: 0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.cyan.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ONPageIndicator(
                    pageCount: _totalCards,
                    currentPage: _currentIndex,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentIndex + 1} / $_totalCards',
                  style: _rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.cyan,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ONHudFrame(
              bracketSize: 12,
              color: colors.cyan,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Center(
                child: Text(
                  'SELECCIONA TU MEJOR OPCION',
                  style: _rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.cyan,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _buildCardStack(results, _currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack(List<ResultCard> results, int currentIndex) {
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth;
      final progress = _dragProgress(cardWidth);

      final card2Scale = 0.95 + 0.05 * progress.clamp(0.0, 1.0);
      final card2Opacity = 0.65 + 0.35 * progress.clamp(0.0, 1.0);
      final card2Top = 10.0 - 10.0 * progress.clamp(0.0, 1.0);

      final card3Scale = 0.90 + 0.05 * progress.clamp(0.0, 1.0);
      final card3Opacity = 0.45 + 0.2 * progress.clamp(0.0, 1.0);
      final card3Top = 20.0 - 10.0 * progress.clamp(0.0, 1.0);

      final frontOffset = _isDismissing ? _dismissAnimation.value : _dragOffset;
      final frontOpacity = _isDismissing ? _dismissOpacity.value : 1.0;
      final rotation = (frontOffset.dx / cardWidth) * _maxRotation;

      final total = results.length;
      final nextIndex = (currentIndex + 1) % total;
      final nextNextIndex = (currentIndex + 2) % total;

      return Stack(
        children: [
          if (total >= 3)
            Positioned(
              top: card3Top,
              left: 10,
              right: 10,
              child: Transform.scale(
                scale: card3Scale.clamp(0.85, 0.95),
                child: Opacity(
                  opacity: card3Opacity.clamp(0.4, 0.65),
                  child: _buildCard(results[nextNextIndex], false),
                ),
              ),
            ),
          if (total >= 2)
            Positioned(
              top: card2Top.clamp(0.0, 10.0),
              left: 5,
              right: 5,
              child: Transform.scale(
                scale: card2Scale.clamp(0.9, 1.0),
                child: Opacity(
                  opacity: card2Opacity.clamp(0.6, 1.0),
                  child: _buildCard(results[nextIndex], false),
                ),
              ),
            ),
          Positioned(
            top: frontOffset.dy,
            left: frontOffset.dx,
            right: -frontOffset.dx,
            child: GestureDetector(
              onPanUpdate: (d) => _onDragUpdate(d, cardWidth),
              onPanEnd: (d) => _onDragEnd(d, cardWidth),
              child: Opacity(
                opacity: frontOpacity.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: rotation,
                  child: _buildCard(results[currentIndex], true),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCard(ResultCard result, bool isTopCard) {
    final colors = ONColors.of(context);
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 18),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface2,
            border: Border.all(
              color: colors.cyan.withValues(alpha: isTopCard ? 0.5 : 0.25),
              width: 1.0,
            ),
            boxShadow: isTopCard
                ? [
                    BoxShadow(
                      color: colors.cyanGlow.withValues(alpha: 0.20),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(result, colors, avatarUrl),
              const SizedBox(height: 6),
              _buildStaffRow(result, colors),
              const ONCyanDivider(),
              _buildTimeSlot(result, colors),
              const SizedBox(height: 10),
              _buildPriceRow(result, colors),
              const SizedBox(height: 8),
              _buildTransportRow(result, colors),
              if (result.transport.mode == 'uber') ...[
                const SizedBox(height: 4),
                _buildPickupRow(colors),
              ],
              if (result.reviewSnippet != null) ...[
                const SizedBox(height: 10),
                _buildReview(result, colors),
              ],
              if (result.badges.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildBadges(result, colors),
              ],
              const SizedBox(height: 14),
              _buildReservarButton(result, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResultCard result, ONColors colors, String? avatarUrl) {
    return Row(
      children: [
        ONNeonBorder(
          borderRadius: 24,
          color: colors.cyan,
          glowRadius: 8,
          borderWidth: 1.0,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: colors.surface3,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.storefront_rounded, size: 20, color: colors.cyan)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ONGlitchText(
                text: result.business.name.toUpperCase(),
                style: _rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                  letterSpacing: 1.0,
                ),
                interval: const Duration(milliseconds: 4000),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: colors.cyan, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: _sourceSans(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildStaffRow(ResultCard result, ONColors colors) {
    String staffText = result.staff.name.toUpperCase();
    if (result.staff.experienceYears != null && result.staff.experienceYears! > 0) {
      staffText += ' // ${result.staff.experienceYears}A EXP';
    }
    return Text(
      staffText,
      style: _rajdhani(
        fontSize: 12,
        color: colors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTimeSlot(ResultCard result, ONColors colors) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime).toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (b) => onCyanGradient.createShader(b),
          child: Text(
            formattedTime,
            style: _rajdhani(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showTimeOverride(context),
          child: Text(
            '// CAMBIAR HORA',
            style: _rajdhani(
              fontSize: 11,
              color: colors.cyan.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(ResultCard result, ONColors colors) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) => onCyanGradient.createShader(b),
          child: Text(
            '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
            style: _rajdhani(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'PROM: \$${result.areaAvgPrice.toStringAsFixed(0)}',
          style: _rajdhani(
            fontSize: 11,
            color: colors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportRow(ResultCard result, ONColors colors) {
    final icon = _getTransportIcon(result.transport.mode);
    final info = _formatTransportInfo(result.transport);
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.cyan.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            info,
            style: _rajdhani(
              fontSize: 11,
              color: colors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupRow(ONColors colors) {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustom = bookingState.customPickupAddress != null;
    final label = (hasCustom ? bookingState.customPickupAddress! : 'UBICACION ACTUAL').toUpperCase();
    return Row(
      children: [
        const SizedBox(width: 24),
        Icon(Icons.trip_origin_rounded, size: 12, color: hasCustom ? colors.green : colors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: _rajdhani(fontSize: 10, color: colors.textMuted, letterSpacing: 0.8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showPickupPicker,
          child: Text(
            'CAMBIAR',
            style: _rajdhani(
              fontSize: 10,
              color: colors.cyan,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPickupPicker() async {
    final location = await showLocationPicker(
      context: context,
      ref: ref,
      title: 'Punto de recogida',
      currentAddress: ref.read(bookingFlowProvider).customPickupAddress,
      showUberPlaces: true,
    );
    if (location != null) {
      ref.read(bookingFlowProvider.notifier).setPickupLocation(
            location.lat, location.lng, location.address,
          );
    }
  }

  Widget _buildReview(ResultCard result, ONColors colors) {
    final snippet = result.reviewSnippet!;
    return ONHudFrame(
      bracketSize: 10,
      color: colors.cyan,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: _sourceSans(
              fontSize: 12,
              color: colors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!snippet.isFallback) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '// ${snippet.authorName?.toUpperCase() ?? "CLIENTE"} · HACE ${snippet.daysAgo ?? 0}D',
                  style: _rajdhani(
                    fontSize: 9,
                    color: colors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 6),
                ...List.generate(
                  snippet.rating ?? 0,
                  (_) => Icon(Icons.star, size: 9, color: colors.cyan),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result, ONColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: result.badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.cyanDark.withValues(alpha: 0.6),
            border: Border.all(color: colors.cyan.withValues(alpha: 0.4), width: 0.5),
          ),
          child: Text(
            _formatBadge(badge),
            style: _rajdhani(
              fontSize: 9,
              color: colors.cyan,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReservarButton(ResultCard result, ONColors colors) {
    return GestureDetector(
      onTap: _isBooking
          ? null
          : () async {
              setState(() => _isBooking = true);
              try {
                ref.read(bookingFlowProvider.notifier).selectResult(result);
              } finally {
                if (mounted) setState(() => _isBooking = false);
              }
            },
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: onCyanGradient,
            boxShadow: [
              BoxShadow(
                color: onCyan.withValues(alpha: 0.35),
                blurRadius: 12,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Scan-line sweep overlay
              if (!_isBooking)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ScanLinePainter(
                          progress: _scanController.value,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      );
                    },
                  ),
                ),
              _isBooking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'RESERVAR',
                      style: _rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: onSurface0,
                        letterSpacing: 3.0,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// Scan-line painter: cyan line sweeps left→right across button
class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final x = progress * size.width;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color, color.withValues(alpha: 0.0)],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(x - 20, 0, 40, size.height));

    canvas.drawRect(Rect.fromLTWH(x - 20, 0, 40, size.height), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// No-results fallback — Ocean Noir styled
// ---------------------------------------------------------------------------

class _ONNoResults extends ConsumerWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _ONNoResults({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  TextStyle _rajdhani({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.rajdhani(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ONColors.of(context);
    final loc = userLocation;
    final serviceQuery = serviceType ?? serviceName;
    final salonsAsync = loc != null
        ? ref.watch(nearbySalonsProvider((
            lat: loc.lat, lng: loc.lng, limit: 10, serviceQuery: serviceQuery,
          )))
        : null;

    return Scaffold(
      backgroundColor: colors.surface0,
      appBar: AppBar(
        backgroundColor: colors.surface0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.cyan),
          onPressed: onGoBack,
        ),
        title: Text(
          'SIN RESULTADOS',
          style: _rajdhani(
            fontWeight: FontWeight.w700,
            color: colors.cyan,
            fontSize: 16,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: salonsAsync == null
          ? Center(
              child: Text(
                'ACTIVA EL GPS PARA VER ESTILISTAS CERCANOS',
                style: _rajdhani(fontSize: 13, color: colors.textSecondary, letterSpacing: 1.0),
                textAlign: TextAlign.center,
              ),
            )
          : salonsAsync.when(
              loading: () => const Center(child: ONDataDots()),
              error: (e, _) => Center(
                child: Text(
                  'ERROR: $e',
                  style: _rajdhani(color: colors.red),
                ),
              ),
              data: (salons) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (hasOverride) ...[
                    ONAngularCard(
                      clipSize: 10,
                      background: colors.surface2,
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_off, color: colors.cyan, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'FILTRO DE HORARIO SIN RESULTADOS',
                              style: _rajdhani(
                                fontSize: 12,
                                color: colors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClearOverride,
                            child: Text(
                              'QUITAR',
                              style: _rajdhani(
                                fontSize: 11,
                                color: colors.cyan,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...salons.map((s) => _ONSalonCard(salon: s)),
                  if (salons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          'NO HAY ESTILISTAS EN TU ZONA',
                          style: _rajdhani(
                            color: colors.textMuted,
                            letterSpacing: 1.5,
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

class _ONSalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  const _ONSalonCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    final colors = ONColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface2,
            border: Border.all(color: colors.cyan.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.surface3,
                backgroundImage:
                    salon.photoUrl != null ? NetworkImage(salon.photoUrl!) : null,
                child: salon.photoUrl == null
                    ? Icon(Icons.store, color: colors.cyan, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (salon.rating != null)
                      Row(
                        children: [
                          Icon(Icons.star, size: 11, color: colors.cyan),
                          const SizedBox(width: 3),
                          Text(
                            salon.rating!.toStringAsFixed(1),
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          if (salon.distanceKm != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${salon.distanceKm!.toStringAsFixed(1)} KM',
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                color: colors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
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
