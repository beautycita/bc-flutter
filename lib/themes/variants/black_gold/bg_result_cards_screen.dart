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
import 'bg_widgets.dart';

class BGResultCardsScreen extends ConsumerStatefulWidget {
  const BGResultCardsScreen({super.key});

  @override
  ConsumerState<BGResultCardsScreen> createState() =>
      _BGResultCardsScreenState();
}

class _BGResultCardsScreenState extends ConsumerState<BGResultCardsScreen>
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

  // Elegant entrance fade+slide for the whole screen
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  static const double _dismissThreshold = 0.25;
  static const double _velocityThreshold = 800.0;
  static const double _maxRotation = 0.12;
  static const double _verticalDamping = 0.3;

  @override
  void initState() {
    super.initState();

    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 350),
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
      CurvedAnimation(
        parent: _dismissController,
        curve: const Interval(0.5, 1.0),
      ),
    );

    _snapBackController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    )..addListener(() {
        setState(() {
          _dragOffset = _snapBackAnimation.value;
        });
      });

    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _snapBackController, curve: Curves.elasticOut));

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    _entranceController.dispose();
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
    final colors = BGColors.of(context);

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      return _BGNoResults(
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
      backgroundColor: colors.surface0,
      appBar: AppBar(
        backgroundColor: colors.surface0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.goldMid, size: 22),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: Text(
          serviceName.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.goldDark.withValues(alpha: 0.0),
                  colors.goldMid.withValues(alpha: 0.5),
                  colors.goldDark.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _entranceFade,
        child: SlideTransition(
          position: _entranceSlide,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  children: [
                    Text(
                      'Elige tu mejor opcion',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const BGGoldDivider(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_currentIndex + 1}/$_totalCards',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    letterSpacing: 2.0,
                    color: colors.goldMid.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _buildCardStack(results, _currentIndex),
              ),
            ],
          ),
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
      final card2Top = 12.0 - 12.0 * progress.clamp(0.0, 1.0);

      final card3Scale = 0.90 + 0.05 * progress.clamp(0.0, 1.0);
      final card3Opacity = 0.4 + 0.2 * progress.clamp(0.0, 1.0);
      final card3Top = 24.0 - 12.0 * progress.clamp(0.0, 1.0);

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
              left: 12,
              right: 12,
              child: Transform.scale(
                scale: card3Scale.clamp(0.85, 0.95),
                child: Opacity(
                  opacity: card3Opacity.clamp(0.3, 0.6),
                  child: _buildCard(results[nextNextIndex], false),
                ),
              ),
            ),
          if (total >= 2)
            Positioned(
              top: card2Top.clamp(0.0, 12.0),
              left: 6,
              right: 6,
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
    final colors = BGColors.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: colors.goldGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        boxShadow: isTopCard
            ? [
                BoxShadow(
                  color: bgGoldMid.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG - 2),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(result, colors),
            const SizedBox(height: 6),
            _buildStaffRow(result, colors),
            const BGGoldDivider(),
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

  Widget _buildHeader(ResultCard result, BGColors colors) {
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: bgGoldGradient,
          ),
          padding: const EdgeInsets.all(1.5),
          child: CircleAvatar(
            backgroundColor: colors.surface3,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.storefront_rounded, size: 22, color: bgGoldMid)
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
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(Icons.star, color: bgGoldMid, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: GoogleFonts.lato(
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

  Widget _buildStaffRow(ResultCard result, BGColors colors) {
    String staffText = result.staff.name;
    if (result.staff.experienceYears != null && result.staff.experienceYears! > 0) {
      staffText += ' · ${result.staff.experienceYears} anos exp.';
    }
    return Text(
      staffText,
      style: GoogleFonts.lato(
        fontSize: 13,
        color: colors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildTimeSlot(ResultCard result, BGColors colors) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime);
    final capitalizedTime = formattedTime[0].toUpperCase() + formattedTime.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capitalizedTime,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.goldMid,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showTimeOverride(context),
          child: Text(
            'Cambiar hora',
            style: GoogleFonts.lato(
              fontSize: 12,
              color: bgGoldMid.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: bgGoldMid.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(ResultCard result, BGColors colors) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) => bgGoldGradient.createShader(b),
          child: Text(
            '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(prom: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.lato(fontSize: 11, color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTransportRow(ResultCard result, BGColors colors) {
    final icon = _getTransportIcon(result.transport.mode);
    final info = _formatTransportInfo(result.transport);
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textMuted),
        const SizedBox(width: 8),
        Text(info, style: GoogleFonts.lato(fontSize: 13, color: colors.textMuted)),
      ],
    );
  }

  Widget _buildPickupRow(BGColors colors) {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustom = bookingState.customPickupAddress != null;
    final label = hasCustom ? bookingState.customPickupAddress! : 'Ubicacion actual';
    return Row(
      children: [
        const SizedBox(width: 26),
        Icon(
          Icons.trip_origin_rounded,
          size: 13,
          color: hasCustom ? Colors.green.shade400 : colors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.lato(fontSize: 11, color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showPickupPicker,
          child: Text(
            'Cambiar',
            style: GoogleFonts.lato(
              fontSize: 11,
              color: bgGoldMid,
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

  Widget _buildReview(ResultCard result, BGColors colors) {
    final snippet = result.reviewSnippet!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border(
          left: BorderSide(color: bgGoldMid, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.lato(
              fontSize: 13,
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
                  style: GoogleFonts.lato(fontSize: 10, color: colors.textMuted),
                ),
                const SizedBox(width: 6),
                ...List.generate(
                  snippet.rating ?? 0,
                  (_) => Icon(Icons.star, size: 10, color: bgGoldMid),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result, BGColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: result.badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface3,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: Border.all(color: bgGoldMid.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Text(
            _formatBadge(badge),
            style: GoogleFonts.lato(
              fontSize: 10,
              color: colors.goldMid,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReservarButton(ResultCard result, BGColors colors) {
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: bgGoldGradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          boxShadow: [
            BoxShadow(
              color: bgGoldMid.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _isBooking
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: bgSurface0,
                ),
              )
            : BGGoldShimmer(
                child: Text(
                  'RESERVAR',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: bgSurface0,
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-results fallback — Black & Gold styled
// ---------------------------------------------------------------------------

class _BGNoResults extends ConsumerWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _BGNoResults({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = BGColors.of(context);
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
          icon: Icon(Icons.arrow_back_rounded, color: bgGoldMid),
          onPressed: onGoBack,
        ),
        title: Text(
          'Sin resultados',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  bgGoldMid.withValues(alpha: 0.0),
                  bgGoldMid.withValues(alpha: 0.4),
                  bgGoldMid.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          if (salonsAsync == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Activa el GPS para ver estilistas cerca de ti',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: salonsAsync.when(
                loading: () => const Center(child: BGGoldDots()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: GoogleFonts.lato(color: colors.textMuted),
                  ),
                ),
                data: (salons) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (hasOverride) ...[
                      BGLuxuryCard(
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt_off, color: bgGoldMid, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El filtro de horario no encontro opciones',
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: onClearOverride,
                              child: Text(
                                'Quitar',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: bgGoldMid,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (salons.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Text(
                            'No se encontraron estilistas en tu zona',
                            style: GoogleFonts.lato(color: colors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...salons.map((s) => _BGSalonCard(salon: s)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BGSalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  const _BGSalonCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    final colors = BGColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: bgGoldMid.withValues(alpha: 0.18), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: bgSurface3,
              backgroundImage:
                  salon.photoUrl != null ? NetworkImage(salon.photoUrl!) : null,
              child: salon.photoUrl == null
                  ? Icon(Icons.store, color: bgGoldMid, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon.name,
                    style: GoogleFonts.lato(
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
                        Icon(Icons.star, size: 12, color: bgGoldMid),
                        const SizedBox(width: 3),
                        Text(
                          salon.rating!.toStringAsFixed(1),
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (salon.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${salon.distanceKm!.toStringAsFixed(1)} km',
                            style: GoogleFonts.lato(
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
    );
  }
}
