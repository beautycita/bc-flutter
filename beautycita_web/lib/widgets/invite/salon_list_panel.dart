import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/web_invite_provider.dart';
import 'salon_card.dart';

/// Left panel of the master-detail invite layout.
///
/// 420px fixed width, warm off-white background. Contains a sticky search bar
/// with animated placeholder cycling and a scrollable card list with shimmer
/// loading states, staggered entrance animations, and gradient edge masks.
class SalonListPanel extends ConsumerStatefulWidget {
  const SalonListPanel({super.key});

  @override
  ConsumerState<SalonListPanel> createState() => _SalonListPanelState();
}

class _SalonListPanelState extends ConsumerState<SalonListPanel>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Placeholder cycling
  late final AnimationController _placeholderAnim;
  int _placeholderIndex = 0;
  static const _placeholders = [
    'Barberia Orozco...',
    'Studio Queens...',
    'Mi salon favorito...',
  ];

  // Track whether we've seen the first data load for stagger animation
  bool _hasAnimatedEntrance = false;

  @override
  void initState() {
    super.initState();

    _placeholderAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
          });
          _placeholderAnim
            ..reset()
            ..forward();
        }
      });
    _placeholderAnim.forward();
  }

  @override
  void dispose() {
    _placeholderAnim.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(webInviteProvider.notifier).clearSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(webInviteProvider.notifier).searchSalons(value);
    });
  }

  void _onClear() {
    _searchController.clear();
    ref.read(webInviteProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webInviteProvider);

    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildCardArea(state)),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF8F7F5),
      child: Focus(
        onFocusChange: (focused) => setState(() {}),
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFFec4899).withValues(alpha: 0.10),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: _placeholders[_placeholderIndex],
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: _onClear,
                          splashRadius: 18,
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFFec4899),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Card area ───────────────────────────────────────────────────────────

  Widget _buildCardArea(WebInviteState state) {
    final Widget content;

    switch (state.step) {
      case WebInviteStep.loading:
        content = _buildShimmerList(5);
      case WebInviteStep.searching:
        content = _buildShimmerList(3);
      case WebInviteStep.scraping:
        content = _buildScrapingState();
      case WebInviteStep.browsing:
        if (state.salons.isEmpty && state.suggestScrape) {
          content = _buildSuggestScrape(state);
        } else if (state.salons.isEmpty) {
          content = _buildEmptyState();
        } else {
          content = _buildSalonList(state);
        }
      default:
        // salonDetail, generating, readyToSend, sending, sent, error
        // The list remains visible behind the detail panel
        content = _buildSalonList(state);
    }

    // Gradient fade masks at top and bottom of scroll area
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [
          0.0,
          24 / bounds.height,
          1 - 24 / bounds.height,
          1.0,
        ],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: content,
    );
  }

  // ── Shimmer placeholders ────────────────────────────────────────────────

  Widget _buildShimmerList(int count) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => const _ShimmerCard(),
    );
  }

  // ── Scraping (Aphrodite animation) ──────────────────────────────────────

  Widget _buildScrapingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AphroditePulse(),
          const SizedBox(height: 20),
          Text(
            'Buscando tu salon...',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggest scrape ──────────────────────────────────────────────────────

  Widget _buildSuggestScrape(WebInviteState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No lo encontramos',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'Buscar en Google',
              onTap: () {
                final query = state.searchQuery;
                if (query != null && query.isNotEmpty) {
                  ref.read(webInviteProvider.notifier).scrapeAndShow(query);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No hay salones cerca',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  // ── Salon list with staggered entrance ──────────────────────────────────

  Widget _buildSalonList(WebInviteState state) {
    final salons = state.salons;
    final shouldAnimate = !_hasAnimatedEntrance && salons.isNotEmpty;

    if (shouldAnimate) {
      // Mark as animated after this frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _hasAnimatedEntrance = true);
        }
      });
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: salons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final salon = salons[index];
        final card = SalonCard(
          salon: salon,
          selected: state.selectedSalon?['id'] == salon['id'],
          onTap: () => ref.read(webInviteProvider.notifier).selectSalon(salon),
        );

        if (shouldAnimate) {
          return _StaggeredEntrance(
            delay: Duration(milliseconds: 50 * index),
            child: card,
          );
        }
        return card;
      },
    );
  }
}

// ── Shimmer card placeholder ──────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
      builder: (_, __) {
        final opacity = 0.08 + (_controller.value * 0.12);
        return Container(
          height: 84,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: opacity + 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity + 0.04),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity + 0.02),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Aphrodite pulsing gradient circle ─────────────────────────────────────

class _AphroditePulse extends StatefulWidget {
  @override
  State<_AphroditePulse> createState() => _AphroditePulseState();
}

class _AphroditePulseState extends State<_AphroditePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(
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
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFec4899), Color(0xFF9333ea)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

// ── Staggered entrance animation ──────────────────────────────────────────

class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({
    required this.delay,
    required this.child,
  });

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _visible ? 0.0 : 0.0, end: _visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── Gradient button ───────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFec4899), Color(0xFF9333ea)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: const Color(0xFFec4899).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
