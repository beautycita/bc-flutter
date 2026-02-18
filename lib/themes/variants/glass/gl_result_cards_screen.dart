import 'dart:ui';
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
import 'gl_widgets.dart';

class GLResultCardsScreen extends ConsumerStatefulWidget {
  const GLResultCardsScreen({super.key});

  @override
  ConsumerState<GLResultCardsScreen> createState() =>
      _GLResultCardsScreenState();
}

class _GLResultCardsScreenState extends ConsumerState<GLResultCardsScreen>
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

  // Neon pulse animation for RESERVAR button
  late AnimationController _pulseController;

  static const double _dismissThreshold = 0.25;
  static const double _velocityThreshold = 800.0;
  static const double _maxRotation = 0.12;
  static const double _verticalDamping = 0.3;

  @override
  void initState() {
    super.initState();

    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    _pulseController.dispose();
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
      case 'available_today': return 'Disponible hoy';
      case 'walk_in_ok': return 'Sin cita';
      case 'new_on_platform': return 'Nuevo en BeautyCita';
      case 'instant_confirm': return 'Confirmacion instantanea';
      default: return k;
    }
  }

  String _formatTrafficLevel(String l) {
    switch (l) {
      case 'light': return 'poco trafico';
      case 'moderate': return 'trafico moderado';
      case 'heavy': return 'mucho trafico';
      default: return l;
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
      return '${t.durationMin} min · ~\$$rMin-\$$rMax ida y vuelta';
    } else if (t.mode == 'transit' && t.transitSummary != null) {
      return '${t.durationMin} min · ${t.transitSummary}';
    }
    return '${t.durationMin} min · ${_formatTrafficLevel(t.trafficLevel)}';
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

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingFlowProvider);
    final bookingNotifier = ref.read(bookingFlowProvider.notifier);
    final colors = GlColors.of(context);

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      return _GLNoResults(
        hasOverride: bookingState.overrideWindow != null,
        userLocation: bookingState.userLocation,
        serviceType: bookingState.serviceType,
        serviceName: bookingState.serviceName,
        onGoBack: () => bookingNotifier.goBack(),
        onClearOverride: () => bookingNotifier.clearOverride(),
      );
    }

    final results = bookingState.curateResponse!.results;
    final serviceName = bookingState.serviceName ?? 'tu servicio';
    _totalCards = results.length;
    if (_currentIndex >= _totalCards) _currentIndex = 0;

    return GlAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.text, size: 22),
            onPressed: () => bookingNotifier.goBack(),
          ),
          title: ShaderMask(
            shaderCallback: (b) => glNeonGradient.createShader(b),
            child: Text(
              serviceName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Ambient floating particles
            ...List.generate(8, (i) => GlFloatingParticle(key: ValueKey(i), index: i)),
            // Content
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: ShaderMask(
                    shaderCallback: (b) => glNeonGradient.createShader(b),
                    child: Text(
                      'Elige tu mejor opcion',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_currentIndex + 1}/$_totalCards',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: glNeonCyan.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildCardStack(results, _currentIndex),
                ),
              ],
            ),
          ],
        ),
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
    final colors = GlColors.of(context);
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
              boxShadow: isTopCard
                  ? [
                      BoxShadow(
                        color: glNeonPink.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(-4, 0),
                      ),
                      BoxShadow(
                        color: glNeonCyan.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(4, 0),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(result, colors, avatarUrl),
                const SizedBox(height: 6),
                _buildStaffRow(result, colors),
                const GlDivider(),
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
                const SizedBox(height: 16),
                _buildReservarButton(result),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResultCard result, GlColors colors, String? avatarUrl) {
    return Row(
      children: [
        IridescentBorder(
          borderRadius: 999,
          borderWidth: 1.5,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: glSurface2.withValues(alpha: 0.7),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.storefront_rounded, size: 20, color: glNeonCyan)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.business.name,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(Icons.star, color: glAmber, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStaffRow(ResultCard result, GlColors colors) {
    String staffText = result.staff.name;
    if (result.staff.experienceYears != null && result.staff.experienceYears! > 0) {
      staffText += ' · ${result.staff.experienceYears} anos exp.';
    }
    return Text(
      staffText,
      style: GoogleFonts.inter(fontSize: 13, color: colors.textMuted),
    );
  }

  Widget _buildTimeSlot(ResultCard result, GlColors colors) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime);
    final capitalizedTime = formattedTime[0].toUpperCase() + formattedTime.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (b) => glNeonGradient.createShader(b),
          child: Text(
            capitalizedTime,
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showTimeOverride(context),
          child: Text(
            'Cambiar hora',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: glNeonCyan.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(ResultCard result, GlColors colors) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) => glNeonGradient.createShader(b),
          child: Text(
            '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(prom: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.inter(fontSize: 11, color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTransportRow(ResultCard result, GlColors colors) {
    final icon = _getTransportIcon(result.transport.mode);
    final info = _formatTransportInfo(result.transport);
    return Row(
      children: [
        Icon(icon, size: 18, color: glNeonCyan.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(info, style: GoogleFonts.inter(fontSize: 12, color: colors.textMuted)),
      ],
    );
  }

  Widget _buildPickupRow(GlColors colors) {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustom = bookingState.customPickupAddress != null;
    final label = hasCustom ? bookingState.customPickupAddress! : 'Ubicacion actual';
    return Row(
      children: [
        const SizedBox(width: 26),
        Icon(Icons.trip_origin_rounded, size: 13, color: hasCustom ? glNeonCyan : colors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showPickupPicker,
          child: Text(
            'Cambiar',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: glNeonCyan,
              fontWeight: FontWeight.w600,
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

  Widget _buildReview(ResultCard result, GlColors colors) {
    final snippet = result.reviewSnippet!;
    return GlFrostedPanel(
      borderRadius: AppConstants.radiusMD,
      padding: const EdgeInsets.all(12),
      tintOpacity: 0.06,
      borderOpacity: 0.12,
      borderColor: glNeonPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: colors.textSecondary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!snippet.isFallback) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '— ${snippet.authorName ?? "Cliente"}, hace ${snippet.daysAgo ?? 0} dias',
                  style: GoogleFonts.inter(fontSize: 10, color: colors.textMuted),
                ),
                const SizedBox(width: 6),
                ...List.generate(
                  snippet.rating ?? 0,
                  (_) => Icon(Icons.star, size: 10, color: glAmber),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result, GlColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: result.badges.map((badge) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                border: Border.all(
                  color: glNeonPurple.withValues(alpha: 0.35),
                  width: 0.5,
                ),
              ),
              child: Text(
                _formatBadge(badge),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: glNeonPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReservarButton(ResultCard result) {
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
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glowIntensity = 0.25 + _pulseController.value * 0.25;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [glNeonPink, glNeonPurple, glNeonCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: glNeonPink.withValues(alpha: glowIntensity),
                  blurRadius: 16,
                  offset: const Offset(-2, 0),
                ),
                BoxShadow(
                  color: glNeonCyan.withValues(alpha: glowIntensity),
                  blurRadius: 16,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _isBooking
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
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-results fallback — Glass styled
// ---------------------------------------------------------------------------

class _GLNoResults extends ConsumerWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _GLNoResults({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GlColors.of(context);
    final loc = userLocation;
    final serviceQuery = serviceType ?? serviceName;
    final salonsAsync = loc != null
        ? ref.watch(nearbySalonsProvider((
            lat: loc.lat, lng: loc.lng, limit: 10, serviceQuery: serviceQuery,
          )))
        : null;

    return GlAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: glNeonCyan),
            onPressed: onGoBack,
          ),
          title: Text(
            'Sin resultados',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: colors.text,
              fontSize: 18,
            ),
          ),
        ),
        body: salonsAsync == null
            ? Center(
                child: Text(
                  'Activa el GPS para ver estilistas cerca de ti',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : salonsAsync.when(
                loading: () => const Center(child: GlNeonDots()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: GoogleFonts.inter(color: colors.textMuted),
                  ),
                ),
                data: (salons) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (hasOverride) ...[
                      GlFrostedPanel(
                        borderRadius: AppConstants.radiusMD,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt_off, color: glNeonCyan, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El filtro de horario no encontro opciones',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: onClearOverride,
                              child: Text(
                                'Quitar',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: glNeonCyan,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ...salons.map((s) => _GLSalonCard(salon: s)),
                    if (salons.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Text(
                            'No se encontraron estilistas en tu zona',
                            style: GoogleFonts.inter(color: colors.textMuted),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GLSalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  const _GLSalonCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    final colors = GlColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: glSurface2.withValues(alpha: 0.5),
                  backgroundImage:
                      salon.photoUrl != null ? NetworkImage(salon.photoUrl!) : null,
                  child: salon.photoUrl == null
                      ? Icon(Icons.store, color: glNeonCyan, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (salon.rating != null)
                        Row(
                          children: [
                            Icon(Icons.star, size: 12, color: glAmber),
                            const SizedBox(width: 3),
                            Text(
                              salon.rating!.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                            if (salon.distanceKm != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${salon.distanceKm!.toStringAsFixed(1)} km',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.textMuted,
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
      ),
    );
  }
}
