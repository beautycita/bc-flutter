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
import 'cb_widgets.dart';

class CBResultCardsScreen extends ConsumerStatefulWidget {
  const CBResultCardsScreen({super.key});

  @override
  ConsumerState<CBResultCardsScreen> createState() =>
      _CBResultCardsScreenState();
}

class _CBResultCardsScreenState extends ConsumerState<CBResultCardsScreen>
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

  static const double _dismissThreshold = 0.25;
  static const double _velocityThreshold = 800.0;
  static const double _maxRotation = 0.10;
  static const double _verticalDamping = 0.3;

  @override
  void initState() {
    super.initState();

    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 320),
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
      duration: const Duration(milliseconds: 420),
      vsync: this,
    )..addListener(() {
        setState(() => _dragOffset = _snapBackAnimation.value);
      });

    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _snapBackController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
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
    final colors = CBColors.of(context);
    final size = MediaQuery.of(context).size;

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      return _CBNoResults(
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
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.pink, size: 22),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: Text(
          serviceName,
          style: GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background watercolor blobs
          Positioned(
            top: -60,
            right: -40,
            child: CBWatercolorBlob(
              color: cbPink.withValues(alpha: 0.06),
              size: 200,
              seed: 1,
              durationSeconds: 12,
            ),
          ),
          Positioned(
            bottom: 80,
            left: -50,
            child: CBWatercolorBlob(
              color: cbLavender.withValues(alpha: 0.07),
              size: 180,
              seed: 2,
              durationSeconds: 15,
            ),
          ),
          // Floating petals
          ...List.generate(
            6,
            (i) => CBFloatingPetal(
              key: ValueKey(i),
              index: i,
              screenWidth: size.width,
              screenHeight: size.height,
            ),
          ),
          // Content
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  children: [
                    Text(
                      'Elige tu mejor opcion',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    CBAccentLine(width: 48, height: 1),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalCards, (i) {
                    final isActive = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: isActive ? cbPink : cbPink.withValues(alpha: 0.2),
                      ),
                    );
                  }),
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
    final colors = CBColors.of(context);
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;

    return CBWatercolorCard(
      borderRadius: AppConstants.radiusLG,
      padding: const EdgeInsets.all(18),
      elevated: isTopCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(result, colors, avatarUrl),
          const SizedBox(height: 6),
          _buildStaffRow(result, colors),
          const SizedBox(height: 10),
          CBPetalDivider(),
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
    );
  }

  Widget _buildHeader(ResultCard result, CBColors colors, String? avatarUrl) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cbPink.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: cbPink.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: cbPinkLight,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.storefront_rounded, size: 22, color: cbPink)
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
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(Icons.star, color: cbPink, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: colors.textSoft,
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

  Widget _buildStaffRow(ResultCard result, CBColors colors) {
    String staffText = result.staff.name;
    if (result.staff.experienceYears != null && result.staff.experienceYears! > 0) {
      staffText += ' · ${result.staff.experienceYears} anos de experiencia';
    }
    return Text(
      staffText,
      style: GoogleFonts.nunitoSans(
        fontSize: 13,
        color: colors.textSoft.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildTimeSlot(ResultCard result, CBColors colors) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime);
    final capitalizedTime = formattedTime[0].toUpperCase() + formattedTime.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capitalizedTime,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cbPink,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showTimeOverride(context),
          child: Text(
            'Cambiar hora',
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: cbPink.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(ResultCard result, CBColors colors) {
    return Row(
      children: [
        Text(
          '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(prom: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.nunitoSans(
            fontSize: 11,
            color: colors.textSoft.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTransportRow(ResultCard result, CBColors colors) {
    final icon = _getTransportIcon(result.transport.mode);
    final info = _formatTransportInfo(result.transport);
    return Row(
      children: [
        Icon(icon, size: 17, color: cbPink.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(
          info,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            color: colors.textSoft.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupRow(CBColors colors) {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustom = bookingState.customPickupAddress != null;
    final label = hasCustom ? bookingState.customPickupAddress! : 'Ubicacion actual';
    return Row(
      children: [
        const SizedBox(width: 25),
        Icon(
          Icons.trip_origin_rounded,
          size: 12,
          color: hasCustom ? cbPink : colors.textSoft.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunitoSans(fontSize: 11, color: colors.textSoft.withValues(alpha: 0.5)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showPickupPicker,
          child: Text(
            'Cambiar',
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: cbPink,
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

  Widget _buildReview(ResultCard result, CBColors colors) {
    final snippet = result.reviewSnippet!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cbPinkLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cbPink.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: colors.text,
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
                  style: GoogleFonts.nunitoSans(
                    fontSize: 10,
                    color: colors.textSoft.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                ...List.generate(
                  snippet.rating ?? 0,
                  (_) => Icon(Icons.star, size: 10, color: cbPink),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result, CBColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: result.badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cbPinkLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: Border.all(color: cbPink.withValues(alpha: 0.18), width: 0.5),
          ),
          child: Text(
            _formatBadge(badge),
            style: GoogleFonts.nunitoSans(
              fontSize: 10,
              color: cbPink.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReservarButton(ResultCard result, CBColors colors) {
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cbPink, cbLavender],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          boxShadow: [
            BoxShadow(
              color: cbPink.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
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
                'Reservar',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-results fallback — Cherry Blossom styled
// ---------------------------------------------------------------------------

class _CBNoResults extends ConsumerWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _CBNoResults({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CBColors.of(context);
    final loc = userLocation;
    final serviceQuery = serviceType ?? serviceName;
    final salonsAsync = loc != null
        ? ref.watch(nearbySalonsProvider((
            lat: loc.lat, lng: loc.lng, limit: 10, serviceQuery: serviceQuery,
          )))
        : null;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cbPink),
          onPressed: onGoBack,
        ),
        title: Text(
          'Sin resultados',
          style: GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: salonsAsync == null
          ? Center(
              child: Text(
                'Activa el GPS para ver estilistas cerca de ti',
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  color: colors.textSoft,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : salonsAsync.when(
              loading: () => const Center(child: CBLoadingDots()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: GoogleFonts.nunitoSans(color: colors.textSoft.withValues(alpha: 0.5)),
                ),
              ),
              data: (salons) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (hasOverride) ...[
                    CBWatercolorCard(
                      borderRadius: AppConstants.radiusMD,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_off, color: cbPink, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El filtro de horario no encontro opciones',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                color: colors.textSoft,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClearOverride,
                            child: Text(
                              'Quitar',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: cbPink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...salons.map((s) => _CBSalonCard(salon: s)),
                  if (salons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          'No se encontraron estilistas en tu zona',
                          style: GoogleFonts.nunitoSans(
                            color: colors.textSoft.withValues(alpha: 0.5),
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

class _CBSalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  const _CBSalonCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    final colors = CBColors.of(context);
    return CBWatercolorCard(
      borderRadius: AppConstants.radiusMD,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cbPink.withValues(alpha: 0.2), width: 1),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: cbPinkLight,
              backgroundImage:
                  salon.photoUrl != null ? NetworkImage(salon.photoUrl!) : null,
              child: salon.photoUrl == null
                  ? Icon(Icons.store, color: cbPink, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salon.name,
                  style: GoogleFonts.nunitoSans(
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
                      Icon(Icons.star, size: 12, color: cbPink),
                      const SizedBox(width: 3),
                      Text(
                        salon.rating!.toStringAsFixed(1),
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: colors.textSoft,
                        ),
                      ),
                      if (salon.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${salon.distanceKm!.toStringAsFixed(1)} km',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            color: colors.textSoft.withValues(alpha: 0.5),
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
    );
  }
}
