import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/security_provider.dart';
import '../services/supabase_client.dart';
import '../services/toast_service.dart';
import '../widgets/cinematic_question_text.dart';
import '../providers/feature_toggle_provider.dart';
import 'invite_salon_screen.dart' show DiscoveredSalon, nearbySalonsProvider, waGreen, waLightGreen, waCardTint;
import 'time_override_sheet.dart';

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

  /// Silk reveal: shadow arrives 50ms before card content slides into place.
  Widget _staggerChild(int index, Widget child) {
    final route = ModalRoute.of(context);
    final anim = route?.animation;
    if (anim == null || anim.isCompleted) return child;

    // Each element staggers by 50ms worth of animation progress
    final slot = index.clamp(0, 7);
    final start = 0.30 + slot * 0.06;
    final end = (start + 0.30).clamp(0.0, 1.0);

    // Shadow fades in first (starts earlier)
    final shadowCurve = CurvedAnimation(
      parent: anim,
      curve: Interval(start, (start + 0.15).clamp(0.0, 1.0), curve: Curves.easeOutQuart),
    );

    // Content slides up and fades in 50ms later
    final contentCurve = CurvedAnimation(
      parent: anim,
      curve: Interval((start + 0.05).clamp(0.0, 1.0), end, curve: Curves.easeOutQuart),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final shadowOpacity = shadowCurve.value;
        final contentOpacity = contentCurve.value;
        final slideY = (1.0 - contentCurve.value) * 30.0;

        return Transform.translate(
          offset: Offset(0, slideY),
          child: Opacity(
            opacity: contentOpacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06 * shadowOpacity),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
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
        return 'Confirmacion instantanea';
      default:
        return badgeKey;
    }
  }


  void _showTimeOverride(BuildContext context) {
    showBurstBottomSheet(
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
    final palette = Theme.of(context).colorScheme;

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
      backgroundColor: palette.surface,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: palette.onSurface, size: 24),
          onPressed: () => bookingNotifier.goBack(),
        ),
        title: Text(
          'Resultados para $serviceName',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: palette.onSurface,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _staggerChild(0, const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CinematicQuestionText(
              text: 'Elige tu mejor opcion',
              fontSize: 24,
            ),
          )),
          _staggerChild(1, Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_currentIndex + 1}/$_totalCards',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.onSurface.withValues(alpha: 0.5),
              ),
            ),
          )),
          Expanded(
            child: _staggerChild(2, _buildCardStack(results, _currentIndex)),
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
            // Card 3 (bottom) -- only show if 3+ cards
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

            // Card 2 (middle) -- only show if 2+ cards
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
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ext.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBusinessHeader(result),
            if (result.staff != null) ...[
              const SizedBox(height: 8),
              _buildStaffInfo(result),
            ],
            if (result.slot != null) ...[
              const SizedBox(height: 12),
              _buildTimeSlot(result),
            ],
            if (!result.isDiscovered) ...[
              const SizedBox(height: 12),
              _buildPriceInfo(result),
            ],
            if (result.isDiscovered && result.business.workingHours != null) ...[
              const SizedBox(height: 10),
              _buildDiscoveredInfo(result),
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
    final palette = Theme.of(context).colorScheme;
    final avatarUrl = result.staff?.avatarUrl ?? result.business.photoUrl;

    // Rating: use staff rating for registered, Google rating for discovered
    final displayRating = result.staff?.rating ?? result.business.rating;
    final displayReviews = result.staff?.totalReviews ?? result.business.totalReviews ?? 0;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: palette.primary.withValues(alpha: 0.15),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Icon(
                  Icons.storefront_rounded,
                  size: 24,
                  color: palette.primary,
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
                  color: palette.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (displayRating != null)
                Row(
                  children: [
                    const Icon(Icons.star,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 3),
                    Text(
                      '${displayRating.toStringAsFixed(1)} ($displayReviews)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    if (result.isDiscovered) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Google',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: palette.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffInfo(ResultCard result) {
    final palette = Theme.of(context).colorScheme;
    final staff = result.staff;
    if (staff == null) return const SizedBox.shrink();

    String staffText = staff.name;
    if (staff.experienceYears != null && staff.experienceYears! > 0) {
      staffText += ' · ${staff.experienceYears} años de experiencia';
    }

    return Text(
      staffText,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: palette.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildDiscoveredInfo(ResultCard result) {
    final palette = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.business.workingHours != null)
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: palette.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  result.business.workingHours!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: palette.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (result.business.address != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: palette.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  result.business.address!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: palette.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeSlot(ResultCard result) {
    final palette = Theme.of(context).colorScheme;
    if (result.slot == null) return const SizedBox.shrink();
    final formatter = DateFormat('EEEE HH:mm', 'es');
    final formattedTime = formatter.format(result.slot!.startTime);
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
            color: palette.onSurface,
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
            'Otro horario?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: palette.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInfo(ResultCard result) {
    final palette = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          '\$${result.service.price?.toStringAsFixed(0) ?? '—'} ${result.service.currency}',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(promedio: \$${result.areaAvgPrice.toStringAsFixed(0)})',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: palette.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSnippet(ResultCard result) {
    final palette = Theme.of(context).colorScheme;
    final snippet = result.reviewSnippet!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${snippet.text}"',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: palette.onSurface,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!snippet.isFallback) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '— ${snippet.authorName ?? "Cliente"}, hace ${snippet.daysAgo ?? 0} dias',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: palette.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    snippet.rating?.round() ?? 0,
                    (index) => const Icon(
                      Icons.star,
                      size: 12,
                      color: Color(0xFFF59E0B),
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
    final palette = Theme.of(context).colorScheme;

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
              color: palette.onSurface,
            ),
          ),
          backgroundColor: palette.surface,
          side: BorderSide(
              color: palette.onSurface.withValues(alpha: 0.15)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(ResultCard result) {
    // Discovered salons: WhatsApp contact button
    if (result.isDiscovered) {
      return GestureDetector(
        onTap: () async {
          final phone = result.business.whatsapp;
          if (phone == null || phone.isEmpty) {
            ToastService.showInfo('Sin número de contacto');
            return;
          }
          final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
          final serviceName = result.service.name;
          final message = Uri.encodeComponent(
            'Hola! Vi su salón en BeautyCita y me interesa agendar una cita de $serviceName. ¿Tienen disponibilidad?',
          );
          final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF25D366).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'CONTACTAR POR WHATSAPP',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Registered businesses: RESERVAR button
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
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withValues(alpha: 0.3),
              blurRadius: 12,
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
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
      ),
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
    // No service filtering — these are salons to invite, show all nearby
    final salonsAsync = loc != null
        ? ref.watch(nearbySalonsProvider((
            lat: loc.lat,
            lng: loc.lng,
            limit: 20,
            serviceQuery: null,
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
              decoration: BoxDecoration(
                color: const Color(0xFFECE5DD),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusLG),
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
    final palette = Theme.of(context).colorScheme;

    if (salonsAsync == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Activa el GPS para ver estilistas cerca de ti',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.onSurface,
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
          style: GoogleFonts.nunito(color: palette.onSurface.withValues(alpha: 0.5)),
          textAlign: TextAlign.center,
        ),
      ),
      data: (salons) {
        final preview = salons.take(20).toList();
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Time override filter removal
            if (widget.hasOverride) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
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
                        color: palette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.filter_alt_off, size: 18, color: palette.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El filtro de horario no encontro opciones',
                        style: GoogleFonts.nunito(fontSize: 13, color: palette.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClearOverride,
                      style: TextButton.styleFrom(
                        backgroundColor: palette.primary.withValues(alpha: 0.1),
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
                          color: palette.primary,
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
                  style: GoogleFonts.nunito(fontSize: 12, color: palette.onSurface.withValues(alpha: 0.5)),
                ),
              ),

            // Preview of first 3 salons
            ...preview.map((salon) {
              final referralsOn = ref.watch(featureTogglesProvider).isEnabled('enable_referrals');
              return _NearbySalonCard(
                salon: salon,
                invited: _invitedIds.contains(salon.id),
                onTap: () => context.push('/discovered-salon', extra: salon),
                onInvite: referralsOn ? () => _handleInvite(salon) : () {},
                hideInvite: !referralsOn,
              );
            }),

            const SizedBox(height: 16),

            if (salons.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'No se encontraron estilistas en tu zona',
                    style: GoogleFonts.nunito(fontSize: 14, color: palette.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleInvite(DiscoveredSalon salon) {
    // Identity gate: verified phone OR verified email required
    final profile = ref.read(profileProvider);
    final sec = ref.read(securityProvider);
    if (!profile.hasVerifiedPhone && !sec.isEmailConfirmed) {
      ToastService.showWarning(
        'Verifica tu telefono o email en Ajustes > Seguridad para invitar salones.',
      );
      return;
    }

    setState(() => _invitedIds.add(salon.id));

    final phone = salon.whatsapp ?? salon.phone;
    if (phone != null) {
      final params = <String, String>{
        if (salon.name.isNotEmpty) 'name': salon.name,
        'phone': phone,
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
  final bool hideInvite;

  const _NearbySalonCard({
    required this.salon,
    required this.invited,
    required this.onTap,
    required this.onInvite,
    this.hideInvite = false,
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
    final palette = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.invited ? waCardTint : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
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
                          errorBuilder: (_, _, _) => _defaultAvatar(),
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
                        color: palette.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.salon.rating != null) ...[
                          const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            widget.salon.rating!.toStringAsFixed(1),
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.onSurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (widget.salon.distanceKm != null)
                          Text(
                            '${widget.salon.distanceKm!.toStringAsFixed(1)} km',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: palette.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Breathing invite button - subtle animation (hidden when referrals disabled)
              if (!widget.hideInvite) AnimatedBuilder(
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
