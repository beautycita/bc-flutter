import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/curate_result.dart';
import '../providers/booking_flow_provider.dart';
import 'time_override_sheet.dart';

class ResultCardsScreen extends ConsumerStatefulWidget {
  const ResultCardsScreen({super.key});

  @override
  ConsumerState<ResultCardsScreen> createState() => _ResultCardsScreenState();
}

class _ResultCardsScreenState extends ConsumerState<ResultCardsScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  void _onCardDismissed() {
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double cardWidth) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta;
    });
  }

  void _onDragEnd(DragEndDetails details, double cardWidth) {
    if (_dragOffset.dx.abs() > cardWidth * 0.4) {
      _onCardDismissed();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
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
      body: remainingCards == 0
          ? _buildNoMoreCards()
          : _buildCardStack(results, _currentIndex),
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

        return Stack(
          children: [
            // Card 3 (bottom)
            if (currentIndex + 2 < results.length)
              Positioned(
                top: 20,
                left: 10,
                right: 10,
                child: Transform.scale(
                  scale: 0.90,
                  child: Opacity(
                    opacity: 0.5,
                    child: _buildCard(results[currentIndex + 2], false),
                  ),
                ),
              ),

            // Card 2 (middle)
            if (currentIndex + 1 < results.length)
              Positioned(
                top: 10,
                left: 5,
                right: 5,
                child: Transform.scale(
                  scale: 0.95,
                  child: Opacity(
                    opacity: 0.7,
                    child: _buildCard(results[currentIndex + 1], false),
                  ),
                ),
              ),

            // Card 1 (top, draggable)
            AnimatedPositioned(
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              top: _dragOffset.dy,
              left: _dragOffset.dx,
              right: -_dragOffset.dx,
              child: GestureDetector(
                onPanUpdate: (details) => _onDragUpdate(details, cardWidth),
                onPanEnd: (details) => _onDragEnd(details, cardWidth),
                child: Transform.rotate(
                  angle: _dragOffset.dx / 1000,
                  child: _buildCard(results[currentIndex], true),
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
