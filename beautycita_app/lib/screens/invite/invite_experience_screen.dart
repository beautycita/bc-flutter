import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../config/theme_extension.dart';
import '../../providers/feature_toggle_provider.dart';
import '../../providers/invite_provider.dart';
import '../invite_salon_screen.dart' show DiscoveredSalon;

/// Main invite experience screen — search bar + weighted salon list.
///
/// Accepts an optional [serviceType] from the booking flow fallback.
/// When null, opened from home nav button (general invite).
class InviteExperienceScreen extends ConsumerStatefulWidget {
  final String? serviceType;

  const InviteExperienceScreen({super.key, this.serviceType});

  @override
  ConsumerState<InviteExperienceScreen> createState() =>
      _InviteExperienceScreenState();
}

class _InviteExperienceScreenState
    extends ConsumerState<InviteExperienceScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(inviteProvider.notifier)
          .initialize(serviceType: widget.serviceType);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) return;
    _debounce = Timer(AppConstants.searchDebounce, () {
      ref.read(inviteProvider.notifier).searchSalons(query.trim());
    });
  }

  void _onClearSearch() {
    _searchController.clear();
    ref.read(inviteProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteProvider);
    final theme = Theme.of(context);
    final bcTheme = theme.extension<BCThemeExtension>();

    // Listen for step changes to navigate to detail screen
    ref.listen<InviteState>(inviteProvider, (prev, next) {
      if (next.step == InviteStep.salonDetail &&
          prev?.step != InviteStep.salonDetail &&
          next.selectedSalon != null) {
        context.push('/invite/detail');
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Invita tu salon',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          // Sticky search bar
          _InviteSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _onClearSearch,
            onSubmitted: (q) {
              _debounce?.cancel();
              if (q.trim().isNotEmpty) {
                ref.read(inviteProvider.notifier).searchSalons(q.trim());
              }
            },
          ),

          // Content area
          Expanded(
            child: _buildContent(state, bcTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(InviteState state, BCThemeExtension? bcTheme) {
    switch (state.step) {
      case InviteStep.loading:
        return const Center(child: CircularProgressIndicator());

      case InviteStep.searching:
        return const _ShimmerSalonList();

      case InviteStep.scraping:
        return _AphroditeLoadingAnimation(bcTheme: bcTheme);

      case InviteStep.error:
        return _ErrorContent(
          message: state.error ?? AppConstants.errorGeneric,
          onRetry: () {
            ref
                .read(inviteProvider.notifier)
                .initialize(serviceType: widget.serviceType);
          },
        );

      case InviteStep.browsing:
        final scrapeEnabled = ref.watch(featureTogglesProvider).isEnabled('enable_on_demand_scrape');
        if (state.salons.isEmpty && state.suggestScrape && scrapeEnabled) {
          return _ScrapePrompt(
            searchQuery: state.searchQuery ?? '',
            onScrape: () {
              final query = state.searchQuery;
              if (query != null && query.isNotEmpty) {
                ref.read(inviteProvider.notifier).scrapeAndShow(query);
              }
            },
          );
        }
        if (state.salons.isEmpty) {
          return _EmptyState(hasSearch: state.searchQuery != null);
        }
        return _SalonListView(
          salons: state.salons,
          onTap: (salon) {
            ref.read(inviteProvider.notifier).selectSalon(salon);
          },
        );

      // These states are handled by the detail screen (Task 8)
      case InviteStep.salonDetail:
      case InviteStep.generating:
      case InviteStep.readyToSend:
      case InviteStep.sending:
      case InviteStep.sent:
        // Still show the list behind while detail screen is pushed
        return _SalonListView(
          salons: state.salons,
          onTap: (salon) {
            ref.read(inviteProvider.notifier).selectSalon(salon);
          },
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Search Bar
// ---------------------------------------------------------------------------

class _InviteSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const _InviteSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingSM,
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingMD,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.nunito(fontSize: 14, color: BeautyCitaTheme.textDark),
        decoration: InputDecoration(
          hintText: 'Buscar salon por nombre...',
          hintStyle: GoogleFonts.nunito(
            fontSize: 14,
            color: BeautyCitaTheme.textLight,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: BeautyCitaTheme.textLight,
          ),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClear,
                color: BeautyCitaTheme.textLight,
              );
            },
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingSM + 2,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Salon List
// ---------------------------------------------------------------------------

class _SalonListView extends StatelessWidget {
  final List<DiscoveredSalon> salons;
  final ValueChanged<DiscoveredSalon> onTap;

  const _SalonListView({required this.salons, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
      ),
      itemCount: salons.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppConstants.paddingSM),
      itemBuilder: (context, index) {
        return _SalonCard(
          salon: salons[index],
          onTap: () => onTap(salons[index]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Salon Card
// ---------------------------------------------------------------------------

class _SalonCard extends StatelessWidget {
  final DiscoveredSalon salon;
  final VoidCallback onTap;

  const _SalonCard({required this.salon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      elevation: AppConstants.elevationLow,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingSM + 4),
          child: Row(
            children: [
              // Photo
              _SalonPhoto(photoUrl: salon.photoUrl),
              const SizedBox(width: AppConstants.paddingSM + 4),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      salon.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // City chip
                    if (salon.city != null && salon.city!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusXS,
                            ),
                          ),
                          child: Text(
                            salon.city!,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                    // Rating + distance row
                    Row(
                      children: [
                        if (salon.rating != null) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: BeautyCitaTheme.secondaryGold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            salon.rating!.toStringAsFixed(1),
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BeautyCitaTheme.textDark,
                            ),
                          ),
                          if (salon.reviewsCount != null &&
                              salon.reviewsCount! > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              '(${salon.reviewsCount})',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: BeautyCitaTheme.textLight,
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                        ],
                        if (salon.distanceKm != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.place_rounded,
                                size: 13,
                                color: BeautyCitaTheme.textLight,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${salon.distanceKm!.toStringAsFixed(1)} km',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: BeautyCitaTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: BeautyCitaTheme.textLight,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Salon Photo / Gradient Placeholder
// ---------------------------------------------------------------------------

class _SalonPhoto extends StatelessWidget {
  final String? photoUrl;

  const _SalonPhoto({required this.photoUrl});

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      child: photoUrl != null
          ? Image.network(
              photoUrl!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, e, st) => _placeholder(context),
            )
          : _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.store_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
        size: 26,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer Loading Cards
// ---------------------------------------------------------------------------

class _ShimmerSalonList extends StatefulWidget {
  const _ShimmerSalonList();

  @override
  State<_ShimmerSalonList> createState() => _ShimmerSalonListState();
}

class _ShimmerSalonListState extends State<_ShimmerSalonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.shimmerAnimation,
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
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingHorizontal,
          ),
          itemCount: 3,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppConstants.paddingSM),
          itemBuilder: (context, index) => _ShimmerCard(progress: _controller.value),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double progress;

  const _ShimmerCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = BeautyCitaTheme.dividerLight;
    final highlightColor = Colors.white;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingSM + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo placeholder
          _shimmerBox(56, 56, AppConstants.radiusSM, shimmerColor,
              highlightColor, progress),
          const SizedBox(width: AppConstants.paddingSM + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(
                    160, 14, 4, shimmerColor, highlightColor, progress),
                const SizedBox(height: 8),
                _shimmerBox(80, 10, 4, shimmerColor, highlightColor, progress),
                const SizedBox(height: 6),
                _shimmerBox(
                    120, 10, 4, shimmerColor, highlightColor, progress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height, double radius,
      Color base, Color highlight, double progress) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [base, highlight, base],
          stops: [
            (progress - 0.3).clamp(0.0, 1.0),
            progress,
            (progress + 0.3).clamp(0.0, 1.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aphrodite Scraping Animation
// ---------------------------------------------------------------------------

class _AphroditeLoadingAnimation extends StatefulWidget {
  final BCThemeExtension? bcTheme;

  const _AphroditeLoadingAnimation({this.bcTheme});

  @override
  State<_AphroditeLoadingAnimation> createState() =>
      _AphroditeLoadingAnimationState();
}

class _AphroditeLoadingAnimationState
    extends State<_AphroditeLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing gradient circle
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: child,
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEC4899), // brand pink
                    const Color(0xFF9333EA), // brand purple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLG),
          Text(
            'Buscando tu salon...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            'Esto puede tomar unos segundos',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: BeautyCitaTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scrape Prompt (salon not found → offer Google scrape)
// ---------------------------------------------------------------------------

class _ScrapePrompt extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onScrape;

  const _ScrapePrompt({required this.searchQuery, required this.onScrape});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: BeautyCitaTheme.textLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              'No encontramos ese salon',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Podemos buscarlo en Google por ti',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: BeautyCitaTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLG),
            // Gradient CTA button
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onScrape,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusFull),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingLG,
                      vertical: AppConstants.paddingSM + 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.travel_explore_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: AppConstants.paddingSM),
                        Text(
                          'Buscarlo en Google',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Empty State (no salons, no scrape suggestion)
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.storefront_rounded,
              size: 56,
              color: BeautyCitaTheme.textLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              hasSearch
                  ? 'No se encontraron salones'
                  : 'No hay salones cerca de ti',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              hasSearch
                  ? 'Intenta con otro nombre o busca en Google'
                  : 'Intenta activar tu GPS o busca por nombre',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: BeautyCitaTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error Content
// ---------------------------------------------------------------------------

class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorContent({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: BeautyCitaTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLG),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Reintentar',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusFull),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLG,
                  vertical: AppConstants.paddingSM + 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
