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
import 'el_widgets.dart';

class ELResultCardsScreen extends ConsumerStatefulWidget {
  const ELResultCardsScreen({super.key});

  @override
  ConsumerState<ELResultCardsScreen> createState() =>
      _ELResultCardsScreenState();
}

class _ELResultCardsScreenState extends ConsumerState<ELResultCardsScreen>
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

  // Art deco shimmer animation for the RESERVAR button
  late AnimationController _shimmerController;

  static const double _dismissThreshold = 0.25;
  static const double _velocityThreshold = 800.0;
  static const double _maxRotation = 0.10;
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

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    _shimmerController.dispose();
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
    final colors = ELColors.of(context);

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      return _ELNoResults(
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
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.gold, size: 22),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => colors.goldGradient.createShader(b),
              child: Text(
                serviceName.toUpperCase(),
                style: GoogleFonts.cinzel(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  elGold.withValues(alpha: 0.0),
                  elGold.withValues(alpha: 0.5),
                  elGold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: ELDecoFrame(
              cornerSize: 14,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (b) => colors.goldGradient.createShader(b),
                  child: Text(
                    'ELIGE TU MEJOR OPCION',
                    style: GoogleFonts.cinzel(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const ELGoldAccent(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalCards, (i) {
                final isActive = i == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 8 : 5,
                      height: isActive ? 8 : 5,
                      decoration: BoxDecoration(
                        color: isActive
                            ? elGold.withValues(alpha: 0.8)
                            : elGold.withValues(alpha: 0.2),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: elGold.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
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
    final colors = ELColors.of(context);
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ELDecoCard(
        cornerLength: 14,
        background: colors.surface,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(result, colors, avatarUrl),
            const SizedBox(height: 6),
            _buildStaffRow(result, colors),
            const ELGoldAccent(showDiamond: false),
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
    );
  }

  Widget _buildHeader(ResultCard result, ELColors colors, String? avatarUrl) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: colors.goldGradient,
          ),
          padding: const EdgeInsets.all(1.5),
          child: CircleAvatar(
            backgroundColor: colors.surface2,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.storefront_rounded, size: 22, color: colors.gold)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => colors.goldGradient.createShader(b),
                child: Text(
                  result.business.name,
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: elGold, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: GoogleFonts.raleway(
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

  Widget _buildStaffRow(ResultCard result, ELColors colors) {
    String staffText = result.staff.name;
    if (result.staff.experienceYears != null && result.staff.experienceYears! > 0) {
      staffText += ' · ${result.staff.experienceYears} anos exp.';
    }
    return Text(
      staffText,
      style: GoogleFonts.raleway(
        fontSize: 12,
        color: colors.textSecondary.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildTimeSlot(ResultCard result, ELColors colors) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime);
    final capitalizedTime = formattedTime[0].toUpperCase() + formattedTime.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (b) => colors.goldGradient.createShader(b),
          child: Text(
            capitalizedTime,
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showTimeOverride(context),
          child: Text(
            'Cambiar hora',
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: elGold.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(ResultCard result, ELColors colors) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) => colors.goldGradient.createShader(b),
          child: Text(
            '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
            style: GoogleFonts.cinzel(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(prom: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.raleway(
            fontSize: 11,
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTransportRow(ResultCard result, ELColors colors) {
    final icon = _getTransportIcon(result.transport.mode);
    final info = _formatTransportInfo(result.transport);
    return Row(
      children: [
        Icon(icon, size: 16, color: elEmerald.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          info,
          style: GoogleFonts.raleway(
            fontSize: 12,
            color: colors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupRow(ELColors colors) {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustom = bookingState.customPickupAddress != null;
    final label = hasCustom ? bookingState.customPickupAddress! : 'Ubicacion actual';
    return Row(
      children: [
        const SizedBox(width: 24),
        Icon(
          Icons.trip_origin_rounded,
          size: 12,
          color: hasCustom ? elEmerald : colors.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.raleway(
              fontSize: 11,
              color: colors.textSecondary.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showPickupPicker,
          child: Text(
            'Cambiar',
            style: GoogleFonts.raleway(
              fontSize: 11,
              color: elGold,
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

  Widget _buildReview(ResultCard result, ELColors colors) {
    final snippet = result.reviewSnippet!;
    return ELDecoCard(
      cornerLength: 10,
      background: colors.surface2,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.raleway(
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
                  style: GoogleFonts.raleway(
                    fontSize: 10,
                    color: colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                ...List.generate(
                  snippet.rating ?? 0,
                  (_) => Icon(Icons.star, size: 10, color: elGold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result, ELColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: result.badges.map((badge) {
        return ClipPath(
          clipper: _OctagonBadgeClipper(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface2,
              border: Border.all(color: elGold.withValues(alpha: 0.35), width: 0.5),
            ),
            child: Text(
              _formatBadge(badge),
              style: GoogleFonts.raleway(
                fontSize: 10,
                color: elGold.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReservarButton(ResultCard result, ELColors colors) {
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
        clipper: const _OctagonButtonClipper(cut: 10),
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final shimmerOffset = _shimmerController.value * 3.0 - 1.0;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [
                    elGold,
                    Color(0xFFFFF8DC),
                    elGoldLight,
                    Color(0xFFFFF8DC),
                    elGold,
                  ],
                  stops: [
                    (shimmerOffset - 0.3).clamp(0.0, 1.0),
                    (shimmerOffset - 0.05).clamp(0.0, 1.0),
                    shimmerOffset.clamp(0.0, 1.0),
                    (shimmerOffset + 0.05).clamp(0.0, 1.0),
                    (shimmerOffset + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [elEmeraldDeep, elEmerald, elEmeraldDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ELDiamondIndicator(size: 5),
                          const SizedBox(width: 12),
                          Text(
                            'RESERVAR',
                            style: GoogleFonts.cinzel(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.0,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ELDiamondIndicator(size: 5),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Minimal octagon clipper for badges
class _OctagonBadgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const c = 4.0;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(_OctagonBadgeClipper _) => false;
}

// Octagon clipper for main RESERVAR button
class _OctagonButtonClipper extends CustomClipper<Path> {
  final double cut;
  const _OctagonButtonClipper({required this.cut});

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_OctagonButtonClipper old) => old.cut != cut;
}

// ---------------------------------------------------------------------------
// No-results fallback — Emerald Luxe styled
// ---------------------------------------------------------------------------

class _ELNoResults extends ConsumerWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _ELNoResults({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ELColors.of(context);
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
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: elGold),
          onPressed: onGoBack,
        ),
        title: ShaderMask(
          shaderCallback: (b) => colors.goldGradient.createShader(b),
          child: Text(
            'SIN RESULTADOS',
            style: GoogleFonts.cinzel(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
      body: salonsAsync == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Activa el GPS para ver estilistas cerca de ti',
                  style: GoogleFonts.raleway(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : salonsAsync.when(
              loading: () => const Center(child: ELGeometricDots()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: GoogleFonts.raleway(color: colors.textSecondary.withValues(alpha: 0.5)),
                ),
              ),
              data: (salons) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (hasOverride) ...[
                    ELDecoCard(
                      cornerLength: 10,
                      background: colors.surface,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_off, color: elGold, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El filtro de horario no encontro opciones',
                              style: GoogleFonts.raleway(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClearOverride,
                            child: Text(
                              'Quitar',
                              style: GoogleFonts.raleway(
                                fontSize: 12,
                                color: elGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...salons.map((s) => _ELSalonCard(salon: s)),
                  if (salons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          'No se encontraron estilistas en tu zona',
                          style: GoogleFonts.raleway(
                            color: colors.textSecondary.withValues(alpha: 0.5),
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

class _ELSalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  const _ELSalonCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    final colors = ELColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ELDecoCard(
        cornerLength: 10,
        background: colors.surface,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: colors.goldGradient,
              ),
              padding: const EdgeInsets.all(1.5),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: colors.surface2,
                backgroundImage:
                    salon.photoUrl != null ? NetworkImage(salon.photoUrl!) : null,
                child: salon.photoUrl == null
                    ? Icon(Icons.store, color: elGold, size: 18)
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
                    style: GoogleFonts.cinzel(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (salon.rating != null)
                    Row(
                      children: [
                        Icon(Icons.star, size: 11, color: elGold),
                        const SizedBox(width: 3),
                        Text(
                          salon.rating!.toStringAsFixed(1),
                          style: GoogleFonts.raleway(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (salon.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${salon.distanceKm!.toStringAsFixed(1)} km',
                            style: GoogleFonts.raleway(
                              fontSize: 12,
                              color: colors.textSecondary.withValues(alpha: 0.5),
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
