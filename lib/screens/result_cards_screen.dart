import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/cinematic_question_text.dart';
import 'time_override_sheet.dart';

class ResultCardsScreen extends ConsumerStatefulWidget {
  const ResultCardsScreen({super.key});

  @override
  ConsumerState<ResultCardsScreen> createState() => _ResultCardsScreenState();
}

class _ResultCardsScreenState extends ConsumerState<ResultCardsScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

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
            _currentIndex++;
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
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _isDragging = false);
        }
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
      _isDragging = true;
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
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => bookingNotifier.goBack(),
          ),
          title: Text(
            'Resultados',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(
          child: Text('No hay resultados disponibles'),
        ),
      );
    }

    final results = bookingState.curateResponse!.results;
    final serviceName = bookingState.serviceName ?? 'tu servicio';

    final remainingCards = results.length - _currentIndex;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.surfaceCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BeautyCitaTheme.textDark),
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
          Expanded(
            child: remainingCards == 0
                ? _buildNoMoreCards()
                : _buildCardStack(results, _currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMoreCards() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: BeautyCitaTheme.surfaceCream,
                shape: BoxShape.circle,
                border: Border.all(
                  color: BeautyCitaTheme.dividerLight,
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text(
                  '\u{1F50D}',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Esas son tus opciones',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Desliza hacia atras para volver a ver',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: BeautyCitaTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

        return Stack(
          children: [
            // Card 3 (bottom)
            if (currentIndex + 2 < results.length)
              Positioned(
                top: card3Top,
                left: 10,
                right: 10,
                child: Transform.scale(
                  scale: card3Scale.clamp(0.85, 0.95),
                  child: Opacity(
                    opacity: card3Opacity.clamp(0.4, 0.7),
                    child: _buildCard(results[currentIndex + 2], false),
                  ),
                ),
              ),

            // Card 2 (middle)
            if (currentIndex + 1 < results.length)
              Positioned(
                top: card2Top.clamp(0.0, 10.0),
                left: 5,
                right: 5,
                child: Transform.scale(
                  scale: card2Scale.clamp(0.9, 1.0),
                  child: Opacity(
                    opacity: card2Opacity.clamp(0.6, 1.0),
                    child: _buildCard(results[currentIndex + 1], false),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      elevation: isTopCard ? 12 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(result),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBusinessHeader(result),
                const SizedBox(height: 12),
                _buildStaffInfo(result),
                const SizedBox(height: 16),
                _buildTimeSlot(result),
                const SizedBox(height: 16),
                _buildPriceInfo(result),
                const SizedBox(height: 12),
                _buildTransportInfo(result),
                if (result.reviewSnippet != null) ...[
                  const SizedBox(height: 16),
                  _buildReviewSnippet(result),
                ],
                if (result.badges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildBadges(result),
                ],
                const SizedBox(height: 20),
                _buildActionButtons(result),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(ResultCard result) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(BeautyCitaTheme.radiusLarge),
          topRight: Radius.circular(BeautyCitaTheme.radiusLarge),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: result.business.photoUrl != null
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(BeautyCitaTheme.radiusLarge),
                topRight: Radius.circular(BeautyCitaTheme.radiusLarge),
              ),
              child: Image.network(
                result.business.photoUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPhotoPlaceholder(),
              ),
            )
          : _buildPhotoPlaceholder(),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8BBD0), Color(0xFFFCE4EC), Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 36,
                color: BeautyCitaTheme.primaryRose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHeader(ResultCard result) {
    return Row(
      children: [
        Expanded(
          child: Text(
            result.business.name,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: BeautyCitaTheme.textDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.star, color: BeautyCitaTheme.secondaryGold, size: 20),
        const SizedBox(width: 4),
        Text(
          '${result.staff.rating.toStringAsFixed(1)} (${result.staff.totalReviews})',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: BeautyCitaTheme.textDark,
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
    return Row(
      children: [
        IconButton(
          onPressed: () {
            debugPrint('TODO: Toggle favorite for ${result.business.name}');
          },
          icon: const Icon(Icons.favorite_border),
          color: BeautyCitaTheme.primaryRose,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              ref.read(bookingFlowProvider.notifier).selectResult(result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BeautyCitaTheme.primaryRose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(BeautyCitaTheme.radiusMedium),
              ),
              elevation: 0,
            ),
            child: Text(
              'RESERVAR',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
