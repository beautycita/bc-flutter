import 'dart:math' as math;
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
import 'mo_widgets.dart';

class MOResultCardsScreen extends ConsumerStatefulWidget {
  const MOResultCardsScreen({super.key});

  @override
  ConsumerState<MOResultCardsScreen> createState() =>
      _MOResultCardsScreenState();
}

class _MOResultCardsScreenState extends ConsumerState<MOResultCardsScreen>
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

  // Orchid pulsing glow for RESERVAR button
  late AnimationController _glowController;

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

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    _glowController.dispose();
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
    final colors = MOColors.of(context);

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      return _MONoResults(
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

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: moOrchidPink, size: 22),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: MOGradientText(
          text: serviceName,
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background particles
          ...List.generate(12, (i) => MOOrchidParticle(key: ValueKey(i), index: i)),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: MOGradientText(
                  text: 'Elige tu mejor opcion',
                  style: GoogleFonts.quicksand(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const MOOrchidDivider(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_currentIndex + 1}/$_totalCards',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: moOrchidPurple.withValues(alpha: 0.7),
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
    final colors = MOColors.of(context);
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;

    // Orchid gradient border wrap
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: moOrchidGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        boxShadow: isTopCard
            ? [
                BoxShadow(
                  color: moOrchidPink.withValues(alpha: 0.30),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG - 2),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(result, colors, avatarUrl),
            const SizedBox(height: 6),
            _buildStaffRow(result, colors),
            const MOOrchidDivider(),
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
            _buildReservarButton(result, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ResultCard result, MOColors colors, String? avatarUrl) {
    return Row(
      children: [
        MOOrchidGlow(
          blurRadius: 16,
          color: moOrchidPink,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: moOrchidDeep.withValues(alpha: 0.5),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.storefront_rounded, size: 22, color: moOrchidPink)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MOGradientText(
                text: result.business.name,
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: moOrchidPink, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: GoogleFonts.quicksand(
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

  Widget _buildStaffRow(ResultCard result, MOColors colors) {
    String staffText = result.staff.name;
    if (result.staff.experienceYears != null && result.staff.experienceYears! > 0) {
      staffText += ' · ${result.staff.experienceYears} anos exp.';
    }
    return Text(
      staffText,
      style: GoogleFonts.quicksand(
        fontSize: 13,
        color: moOrchidPurple.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildTimeSlot(ResultCard result, MOColors colors) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime);
    final capitalizedTime = formattedTime[0].toUpperCase() + formattedTime.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MOGradientText(
          text: capitalizedTime,
          style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showTimeOverride(context),
          child: Text(
            'Cambiar hora',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: moOrchidPink.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(ResultCard result, MOColors colors) {
    return Row(
      children: [
        MOGradientText(
          text: '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
          style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          '(prom: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.quicksand(
            fontSize: 11,
            color: moOrchidPurple.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTransportRow(ResultCard result, MOColors colors) {
    final icon = _getTransportIcon(result.transport.mode);
    final info = _formatTransportInfo(result.transport);
    return Row(
      children: [
        Icon(icon, size: 18, color: moOrchidPurple.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          info,
          style: GoogleFonts.quicksand(
            fontSize: 12,
            color: moOrchidPurple.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupRow(MOColors colors) {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustom = bookingState.customPickupAddress != null;
    final label = hasCustom ? bookingState.customPickupAddress! : 'Ubicacion actual';
    return Row(
      children: [
        const SizedBox(width: 26),
        Icon(
          Icons.trip_origin_rounded,
          size: 13,
          color: hasCustom ? moOrchidPink : moOrchidPurple.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.quicksand(
              fontSize: 11,
              color: moOrchidPurple.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showPickupPicker,
          child: Text(
            'Cambiar',
            style: GoogleFonts.quicksand(
              fontSize: 11,
              color: moOrchidPink,
              fontWeight: FontWeight.w700,
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

  Widget _buildReview(ResultCard result, MOColors colors) {
    final snippet = result.reviewSnippet!;
    return MOGlowCard(
      borderRadius: AppConstants.radiusMD,
      padding: const EdgeInsets.all(12),
      glowIntensity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: moOrchidLight.withValues(alpha: 0.85),
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
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    color: moOrchidPurple.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                ...List.generate(
                  snippet.rating ?? 0,
                  (_) => Icon(Icons.star, size: 10, color: moOrchidPink),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result, MOColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: result.badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: moOrchidDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: Border.all(color: moOrchidPink.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Text(
            _formatBadge(badge),
            style: GoogleFonts.quicksand(
              fontSize: 10,
              color: moOrchidLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReservarButton(ResultCard result, MOColors colors) {
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
        animation: _glowController,
        builder: (context, child) {
          final glowAlpha = 0.25 + _glowController.value * 0.30;
          final scaleFactor = 1.0 + _glowController.value * 0.02;
          return Transform.scale(
            scale: scaleFactor,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: moOrchidGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                boxShadow: [
                  BoxShadow(
                    color: moOrchidPink.withValues(alpha: glowAlpha),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
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
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-results fallback — Midnight Orchid styled
// ---------------------------------------------------------------------------

class _MONoResults extends ConsumerWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _MONoResults({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = MOColors.of(context);
    final loc = userLocation;
    final serviceQuery = serviceType ?? serviceName;
    final salonsAsync = loc != null
        ? ref.watch(nearbySalonsProvider((
            lat: loc.lat, lng: loc.lng, limit: 10, serviceQuery: serviceQuery,
          )))
        : null;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: moOrchidPink),
          onPressed: onGoBack,
        ),
        title: MOGradientText(
          text: 'Sin resultados',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          ...List.generate(8, (i) => MOOrchidParticle(key: ValueKey(i), index: i + 20)),
          salonsAsync == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Activa el GPS para ver estilistas cerca de ti',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : salonsAsync.when(
                  loading: () => const Center(child: MOLoadingDots()),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: GoogleFonts.quicksand(color: moOrchidPurple.withValues(alpha: 0.5)),
                    ),
                  ),
                  data: (salons) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasOverride) ...[
                        MOGlowCard(
                          borderRadius: AppConstants.radiusMD,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt_off, color: moOrchidPink, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'El filtro de horario no encontro opciones',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: onClearOverride,
                                child: Text(
                                  'Quitar',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 12,
                                    color: moOrchidPink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...salons.map((s) => _MOSalonCard(salon: s)),
                      if (salons.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Text(
                              'No se encontraron estilistas en tu zona',
                              style: GoogleFonts.quicksand(
                                color: moOrchidPurple.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class _MOSalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  const _MOSalonCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    final colors = MOColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: moOrchidDeep.withValues(alpha: 0.8), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: moOrchidPink.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: moOrchidDeep.withValues(alpha: 0.5),
              backgroundImage:
                  salon.photoUrl != null ? NetworkImage(salon.photoUrl!) : null,
              child: salon.photoUrl == null
                  ? Icon(Icons.store, color: moOrchidPink, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon.name,
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (salon.rating != null)
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: moOrchidPink),
                        const SizedBox(width: 3),
                        Text(
                          salon.rating!.toStringAsFixed(1),
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (salon.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${salon.distanceKm!.toStringAsFixed(1)} km',
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              color: moOrchidPurple.withValues(alpha: 0.5),
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
    );
  }
}
