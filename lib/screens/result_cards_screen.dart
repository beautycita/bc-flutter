import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../services/places_service.dart';
import '../services/supabase_client.dart';
import '../widgets/cinematic_question_text.dart';
import '../widgets/location_picker_sheet.dart';
import 'invite_salon_screen.dart' show DiscoveredSalon, nearbySalonsProvider, waGreen, waLightGreen, waCardTint;
import 'time_override_sheet.dart';

/// 13-stop real gold gradient for card borders and button.
const _goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF8B6914),
    Color(0xFFD4AF37),
    Color(0xFFFFF8DC),
    Color(0xFFFFD700),
    Color(0xFFC19A26),
    Color(0xFFF5D547),
    Color(0xFFFFFFE0),
    Color(0xFFD4AF37),
    Color(0xFFA67C00),
    Color(0xFFCDAD38),
    Color(0xFFFFF8DC),
    Color(0xFFB8860B),
    Color(0xFF8B6914),
  ],
  stops: [0.0, 0.08, 0.15, 0.25, 0.35, 0.45, 0.50, 0.58, 0.68, 0.78, 0.85, 0.93, 1.0],
);

class ResultCardsScreen extends ConsumerStatefulWidget {
  const ResultCardsScreen({super.key});

  @override
  ConsumerState<ResultCardsScreen> createState() => _ResultCardsScreenState();
}

class _ResultCardsScreenState extends ConsumerState<ResultCardsScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _totalCards = 0;
  Offset _dragOffset = Offset.zero;
  bool _isBooking = false;

  // Animated dismiss: fly-off controller
  late AnimationController _dismissController;
  late Animation<Offset> _dismissAnimation;
  late Animation<double> _dismissOpacity;
  bool _isDismissing = false;
  int _dismissDirection = 1; // 1 = right, -1 = left

  // Snap-back spring controller
  late AnimationController _snapBackController;
  late Animation<Offset> _snapBackAnimation;

  static const double _dismissThreshold = 0.25; // 25% of card width
  static const double _velocityThreshold = 800.0; // px/s flick speed
  static const double _maxRotation = 0.15; // radians (~8.5 degrees)
  static const double _verticalDamping = 0.3; // reduce vertical movement

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
                // Right swipe = advance
                _currentIndex = (_currentIndex + 1) % _totalCards;
              } else {
                // Left swipe = go back
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
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: Curves.easeOut,
    ));

    _dismissOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: const Interval(0.5, 1.0),
    ));

    _snapBackController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..addListener(() {
        setState(() {
          _dragOffset = _snapBackAnimation.value;
        });
      });

    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _snapBackController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  /// Drag progress as fraction of card width (0-1+)
  double _dragProgress(double cardWidth) {
    return cardWidth > 0 ? (_dragOffset.dx.abs() / cardWidth).clamp(0.0, 1.5) : 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details, double cardWidth) {
    if (_isDismissing) return;
    _snapBackController.stop();
    setState(() {
      // Full horizontal, damped vertical
      _dragOffset += Offset(
        details.delta.dx,
        details.delta.dy * _verticalDamping,
      );
    });
  }

  void _onDragEnd(DragEndDetails details, double cardWidth) {
    if (_isDismissing) return;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final distanceThresholdMet = _dragOffset.dx.abs() > cardWidth * _dismissThreshold;
    final velocityThresholdMet = velocity.abs() > _velocityThreshold;

    if (distanceThresholdMet || velocityThresholdMet) {
      // Determine direction from drag offset or velocity
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
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: Curves.easeOut,
    ));

    _dismissOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: const Interval(0.4, 1.0),
    ));

    setState(() => _isDismissing = true);
    _dismissController.forward(from: 0);
  }

  void _animateSnapBack() {
    _snapBackAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _snapBackController,
      curve: Curves.elasticOut,
    ));
    _snapBackController.forward(from: 0);
  }

  String _formatBadge(String badgeKey) {
    switch (badgeKey) {
      case 'available_today':
        return 'Disponible hoy';
      case 'walk_in_ok':
        return 'Sin cita';
      case 'new_on_platform':
        return 'Nuevo en BeautyCita';
      case 'instant_confirm':
        return 'Confirmación instantánea';
      default:
        return badgeKey;
    }
  }

  String _formatTrafficLevel(String level) {
    switch (level) {
      case 'light':
        return 'poco tráfico';
      case 'moderate':
        return 'tráfico moderado';
      case 'heavy':
        return 'mucho tráfico';
      default:
        return level;
    }
  }

  IconData _getTransportIcon(String mode) {
    switch (mode) {
      case 'car':
        return Icons.directions_car;
      case 'uber':
        return Icons.local_taxi;
      case 'transit':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }

  String _formatTransportInfo(TransportInfo transport) {
    if (transport.mode == 'uber' &&
        transport.uberEstimateMin != null &&
        transport.uberEstimateMax != null) {
      final roundTripMin = (transport.uberEstimateMin! * 2).toStringAsFixed(0);
      final roundTripMax = (transport.uberEstimateMax! * 2).toStringAsFixed(0);
      return '${transport.durationMin} min · ~\$$roundTripMin-\$$roundTripMax ida y vuelta';
    } else if (transport.mode == 'transit' && transport.transitSummary != null) {
      return '${transport.durationMin} min · ${transport.transitSummary}';
    } else {
      return '${transport.durationMin} min · ${_formatTrafficLevel(transport.trafficLevel)}';
    }
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

    if (bookingState.curateResponse == null ||
        bookingState.curateResponse!.results.isEmpty) {
      final hasOverride = bookingState.overrideWindow != null;
      final userLoc = bookingState.userLocation;
      return _NoResultsWithNearbySalons(
        hasOverride: hasOverride,
        userLocation: userLoc,
        serviceType: bookingState.serviceType,
        serviceName: bookingState.serviceName,
        onGoBack: () => bookingNotifier.goBack(),
        onClearOverride: () => bookingNotifier.clearOverride(),
      );
    }

    final results = bookingState.curateResponse!.results;
    final serviceName = bookingState.serviceName ?? 'tu servicio';
    _totalCards = results.length;

    // Clamp index in case results changed
    if (_currentIndex >= _totalCards) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.surfaceCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: BeautyCitaTheme.textDark, size: 24),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: Text(
          'Resultados para $serviceName',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: BeautyCitaTheme.textDark,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CinematicQuestionText(
              text: 'Elige tu mejor opcion',
              fontSize: 24,
            ),
          ),
          // Position indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_currentIndex + 1}/$_totalCards',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: BeautyCitaTheme.textLight,
              ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final progress = _dragProgress(cardWidth);

        // Back cards react: scale up and fade in as front card is dragged
        final card2Scale = 0.95 + 0.05 * progress.clamp(0.0, 1.0);
        final card2Opacity = 0.7 + 0.3 * progress.clamp(0.0, 1.0);
        final card2Top = 10.0 - 10.0 * progress.clamp(0.0, 1.0);

        final card3Scale = 0.90 + 0.05 * progress.clamp(0.0, 1.0);
        final card3Opacity = 0.5 + 0.2 * progress.clamp(0.0, 1.0);
        final card3Top = 20.0 - 10.0 * progress.clamp(0.0, 1.0);

        // Front card: current offset (drag or dismiss animation)
        final frontOffset = _isDismissing ? _dismissAnimation.value : _dragOffset;
        final frontOpacity = _isDismissing ? _dismissOpacity.value : 1.0;
        final rotation = (frontOffset.dx / cardWidth) * _maxRotation;

        final total = results.length;
        final nextIndex = (currentIndex + 1) % total;
        final nextNextIndex = (currentIndex + 2) % total;

        return Stack(
          children: [
            // Card 3 (bottom) — only show if 3+ cards
            if (total >= 3)
              Positioned(
                top: card3Top,
                left: 10,
                right: 10,
                child: Transform.scale(
                  scale: card3Scale.clamp(0.85, 0.95),
                  child: Opacity(
                    opacity: card3Opacity.clamp(0.4, 0.7),
                    child: _buildCard(results[nextNextIndex], false),
                  ),
                ),
              ),

            // Card 2 (middle) — only show if 2+ cards
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

            // Card 1 (top, draggable)
            Positioned(
              top: frontOffset.dy,
              left: frontOffset.dx,
              right: -frontOffset.dx,
              child: GestureDetector(
                onPanUpdate: (details) => _onDragUpdate(details, cardWidth),
                onPanEnd: (details) => _onDragEnd(details, cardWidth),
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
      },
    );
  }

  Widget _buildCard(ResultCard result, bool isTopCard) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: _goldGradient,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isTopCard ? 0.15 : 0.05),
            blurRadius: isTopCard ? 12 : 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge - 3),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBusinessHeader(result),
            const SizedBox(height: 8),
            _buildStaffInfo(result),
            const SizedBox(height: 12),
            _buildTimeSlot(result),
            const SizedBox(height: 12),
            _buildPriceInfo(result),
            const SizedBox(height: 8),
            _buildTransportInfo(result),
            if (result.transport.mode == 'uber') ...[
              const SizedBox(height: 4),
              _buildPickupInfo(),
            ],
            if (result.reviewSnippet != null) ...[
              const SizedBox(height: 10),
              _buildReviewSnippet(result),
            ],
            if (result.badges.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildBadges(result),
            ],
            const SizedBox(height: 14),
            _buildActionButtons(result),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHeader(ResultCard result) {
    final avatarUrl = result.staff.avatarUrl ?? result.business.photoUrl;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: BeautyCitaTheme.primaryRose.withValues(alpha: 0.15),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? const Icon(
                  Icons.storefront_rounded,
                  size: 24,
                  color: BeautyCitaTheme.primaryRose,
                )
              : null,
        ),
        const SizedBox(width: 12),
        // Name + rating
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.business.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  const Icon(Icons.star,
                      color: BeautyCitaTheme.secondaryGold, size: 16),
                  const SizedBox(width: 3),
                  Text(
                    '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BeautyCitaTheme.textLight,
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

  Widget _buildStaffInfo(ResultCard result) {
    String staffText = result.staff.name;

    if (result.staff.experienceYears != null &&
        result.staff.experienceYears! > 0) {
      staffText += ' · ${result.staff.experienceYears} años de experiencia';
    }

    return Text(
      staffText,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: BeautyCitaTheme.textLight,
      ),
    );
  }

  Widget _buildTimeSlot(ResultCard result) {
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot.startTime);
    final capitalizedTime =
        formattedTime[0].toUpperCase() + formattedTime.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capitalizedTime,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: BeautyCitaTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _showTimeOverride(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '¿Otro horario?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: BeautyCitaTheme.primaryRose,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInfo(ResultCard result) {
    return Row(
      children: [
        Text(
          '\$${result.service.price.toStringAsFixed(0)} ${result.service.currency}',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: BeautyCitaTheme.textDark,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(promedio: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: BeautyCitaTheme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportInfo(ResultCard result) {
    final transport = result.transport;
    final icon = _getTransportIcon(transport.mode);
    final info = _formatTransportInfo(transport);

    return Row(
      children: [
        Icon(icon, size: 20, color: BeautyCitaTheme.textLight),
        const SizedBox(width: 8),
        Text(
          info,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: BeautyCitaTheme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildPickupInfo() {
    final bookingState = ref.watch(bookingFlowProvider);
    final hasCustomPickup = bookingState.customPickupAddress != null;
    final label = hasCustomPickup
        ? bookingState.customPickupAddress!
        : 'Ubicacion actual';

    return Row(
      children: [
        const SizedBox(width: 28), // align with transport icon
        Icon(
          Icons.trip_origin_rounded,
          size: 14,
          color: hasCustomPickup
              ? Colors.green.shade600
              : BeautyCitaTheme.textLight,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: BeautyCitaTheme.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => _showPickupPicker(),
          child: Text(
            'Cambiar',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: BeautyCitaTheme.primaryRose,
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
            location.lat,
            location.lng,
            location.address,
          );
    }
  }

  Widget _buildReviewSnippet(ResultCard result) {
    final snippet = result.reviewSnippet!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: BeautyCitaTheme.textDark,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!snippet.isFallback) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '— ${snippet.authorName ?? "Cliente"}, hace ${snippet.daysAgo ?? 0} días',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    snippet.rating ?? 0,
                    (index) => const Icon(
                      Icons.star,
                      size: 12,
                      color: BeautyCitaTheme.secondaryGold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadges(ResultCard result) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: result.badges.map((badge) {
        return Chip(
          label: Text(
            _formatBadge(badge),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: BeautyCitaTheme.textDark,
            ),
          ),
          backgroundColor: BeautyCitaTheme.surfaceCream,
          side: BorderSide(
              color: BeautyCitaTheme.textLight.withValues(alpha: 0.3)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(ResultCard result) {
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
          gradient: _goldGradient,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
            : const _GoldShimmerButtonText(text: 'RESERVAR'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gold shimmer text for the RESERVAR button
// ---------------------------------------------------------------------------

class _GoldShimmerButtonText extends StatefulWidget {
  final String text;
  const _GoldShimmerButtonText({required this.text});

  @override
  State<_GoldShimmerButtonText> createState() => _GoldShimmerButtonTextState();
}

class _GoldShimmerButtonTextState extends State<_GoldShimmerButtonText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = _controller.value * 3.0 - 1.0;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF1A1400),
                Color(0xFFFFF8DC),
                Color(0xFFFFFFFF),
                Color(0xFFFFF8DC),
                Color(0xFF1A1400),
              ],
              stops: [
                (shimmerOffset - 0.2).clamp(0.0, 1.0),
                (shimmerOffset - 0.05).clamp(0.0, 1.0),
                shimmerOffset.clamp(0.0, 1.0),
                (shimmerOffset + 0.05).clamp(0.0, 1.0),
                (shimmerOffset + 0.2).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// No-results: WhatsApp-styled nearby salons
// ---------------------------------------------------------------------------

/// Strip non-standard-Latin characters from scraped data
String _sanitizeText(String text) {
  return text.replaceAll(RegExp(r'[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u206F\u2070-\u209F\u20A0-\u20CF\u2100-\u214F\s]'), '').trim();
}

class _NoResultsWithNearbySalons extends ConsumerStatefulWidget {
  final bool hasOverride;
  final LatLng? userLocation;
  final String? serviceType;
  final String? serviceName;
  final VoidCallback onGoBack;
  final VoidCallback onClearOverride;

  const _NoResultsWithNearbySalons({
    required this.hasOverride,
    required this.userLocation,
    this.serviceType,
    this.serviceName,
    required this.onGoBack,
    required this.onClearOverride,
  });

  @override
  ConsumerState<_NoResultsWithNearbySalons> createState() =>
      _NoResultsWithNearbySalonsState();
}

class _NoResultsWithNearbySalonsState
    extends ConsumerState<_NoResultsWithNearbySalons> {
  final Set<String> _invitedIds = {};

  @override
  Widget build(BuildContext context) {
    final loc = widget.userLocation;
    // Build service query from serviceType (machine key) for keyword matching
    final serviceQuery = widget.serviceType ?? widget.serviceName;
    final salonsAsync = loc != null
        ? ref.watch(nearbySalonsProvider((
            lat: loc.lat,
            lng: loc.lng,
            limit: 10,
            serviceQuery: serviceQuery,
          )))
        : null;

    final displayService = widget.serviceName ?? 'este servicio';

    return Scaffold(
      backgroundColor: waGreen,
      appBar: AppBar(
        backgroundColor: waGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: widget.onGoBack,
        ),
        title: Text(
          'Estilistas de $displayService',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'que aun no estan en BeautyCita',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFECE5DD),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(BeautyCitaTheme.radiusLarge),
                ),
              ),
              child: _buildContent(salonsAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<DiscoveredSalon>>? salonsAsync) {
    if (salonsAsync == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Activa el GPS para ver estilistas cerca de ti',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BeautyCitaTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return salonsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: waLightGreen),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: GoogleFonts.nunito(color: BeautyCitaTheme.textLight),
          textAlign: TextAlign.center,
        ),
      ),
      data: (salons) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Time override filter removal
            if (widget.hasOverride) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.filter_alt_off, size: 18, color: BeautyCitaTheme.primaryRose),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El filtro de horario no encontro opciones',
                        style: GoogleFonts.nunito(fontSize: 13, color: BeautyCitaTheme.textLight),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClearOverride,
                      style: TextButton.styleFrom(
                        backgroundColor: BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        'Quitar filtro',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BeautyCitaTheme.primaryRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Count header
            if (salons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${salons.length} estilistas en tu zona',
                  style: GoogleFonts.nunito(fontSize: 12, color: BeautyCitaTheme.textLight),
                ),
              ),

            // Salon cards
            ...salons.map((salon) => _NearbySalonCard(
              salon: salon,
              invited: _invitedIds.contains(salon.id),
              onTap: () => context.push('/discovered-salon', extra: salon),
              onInvite: () => _handleInvite(salon),
            )),

            if (salons.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'No se encontraron estilistas en tu zona',
                    style: GoogleFonts.nunito(fontSize: 14, color: BeautyCitaTheme.textLight),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleInvite(DiscoveredSalon salon) {
    setState(() => _invitedIds.add(salon.id));

    final phone = salon.whatsapp ?? salon.phone;
    if (phone != null) {
      final params = <String, String>{
        if (salon.name.isNotEmpty) 'name': salon.name,
        if (phone != null) 'phone': phone,
        if (salon.address != null) 'address': salon.address!,
        if (salon.city != null) 'city': salon.city!,
        if (salon.photoUrl != null) 'avatar': salon.photoUrl!,
        if (salon.rating != null) 'rating': salon.rating!.toStringAsFixed(1),
        'ref': salon.id,
      };
      final regUrl = Uri.https('beautycita.com', '/registro', params);
      final message = Uri.encodeComponent(
        'Hola! Queria hacer una cita contigo pero no te encontre '
        'en BeautyCita. Deberias estar ahi, te llegan mas clientes '
        'y es gratis: $regUrl '
        'Manana te busco en la app si no ando muy ocupada!',
      );
      final waUrl = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=$message');
      launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }

    // Record interest signal (fire and forget)
    SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'invite',
        'discovered_salon_id': salon.id,
      },
    );
  }
}

class _NearbySalonCard extends StatefulWidget {
  final DiscoveredSalon salon;
  final bool invited;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  const _NearbySalonCard({
    required this.salon,
    required this.invited,
    required this.onTap,
    required this.onInvite,
  });

  @override
  State<_NearbySalonCard> createState() => _NearbySalonCardState();
}

class _NearbySalonCardState extends State<_NearbySalonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );
    if (!widget.invited) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NearbySalonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invited && !oldWidget.invited) {
      _breathingController.stop();
      _breathingController.reset();
    } else if (!widget.invited && oldWidget.invited) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.invited ? waCardTint : Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Photo / avatar with subtle shadow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: widget.salon.photoUrl != null
                      ? Image.network(
                          widget.salon.photoUrl!,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sanitizeText(widget.salon.name),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.salon.rating != null) ...[
                          Icon(Icons.star, size: 14, color: BeautyCitaTheme.secondaryGold),
                          const SizedBox(width: 3),
                          Text(
                            widget.salon.rating!.toStringAsFixed(1),
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BeautyCitaTheme.textDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (widget.salon.distanceKm != null)
                          Text(
                            '${widget.salon.distanceKm!.toStringAsFixed(1)} km',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: BeautyCitaTheme.textLight,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Breathing invite button - subtle animation
              AnimatedBuilder(
                animation: _breathingAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.invited ? 1.0 : _breathingAnimation.value,
                    child: ElevatedButton.icon(
                      onPressed: widget.invited ? null : widget.onInvite,
                      icon: Icon(widget.invited ? Icons.check : Icons.chat, size: 14),
                      label: Text(
                        widget.invited ? 'ENVIADO' : 'INVITAR',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.invited ? Colors.grey[300] : waLightGreen,
                        foregroundColor: widget.invited ? Colors.grey[600] : Colors.white,
                        elevation: widget.invited ? 0 : 3,
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: waGreen.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store, color: waGreen, size: 26),
    );
  }
}
