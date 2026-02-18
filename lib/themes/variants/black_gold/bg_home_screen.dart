import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../config/theme_extension.dart';
import '../../../screens/subcategory_sheet.dart';
import '../../../themes/category_icons.dart';
import '../../../themes/theme_variant.dart';
import 'bg_widgets.dart';

class BGHomeScreen extends ConsumerWidget {
  const BGHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BGColors.of(context);
    final categories = ref.watch(categoriesProvider);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Scaffold(
      backgroundColor: c.surface0,
      // NO bottom nav bar — replaced with floating FAB
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Transparent floating header (SliverAppBar pinned, transparent)
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 0,
                toolbarHeight: 64,
                flexibleSpace: _BGFloatingHeader(ref: ref),
              ),

              // Hero carousel
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: categories.isEmpty
                      ? const SizedBox(
                          height: 280,
                          child: Center(
                            child: BGGoldDots(),
                          ),
                        )
                      : BGHeroCarousel(
                          items: _buildCarouselItems(
                              context, categories, ext, c),
                        ),
                ),
              ),

              // ── Section: Tendencias (story chips) ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 20, top: 24, bottom: 10),
                  child: Text(
                    'TENDENCIAS',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: c.goldMid.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96,
                  child: categories.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, i) {
                            final cat = categories[i];
                            return BGCategoryChip(
                              categoryId: cat.id,
                              label: cat.nameEs,
                              onTap: () =>
                                  _showSubcategorySheet(context, cat),
                            );
                          },
                        ),
                ),
              ),

              // ── Section: Servicios (staggered layout) ──────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 20, top: 24, bottom: 12),
                  child: Text(
                    'SERVICIOS',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: c.goldMid.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

              // Staggered grid: full-width card then pair, alternating
              if (categories.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, groupIndex) {
                        // Each group index = 1 feature + 2 small (3 categories)
                        final base = groupIndex * 3;
                        if (base >= categories.length) return null;

                        return _BGStaggeredGroup(
                          feature: base < categories.length
                              ? categories[base]
                              : null,
                          smallA: base + 1 < categories.length
                              ? categories[base + 1]
                              : null,
                          smallB: base + 2 < categories.length
                              ? categories[base + 2]
                              : null,
                          featureColor: ext.categoryColors.length > base
                              ? ext.categoryColors[base]
                              : c.goldMid,
                          smallAColor: ext.categoryColors.length > base + 1
                              ? ext.categoryColors[base + 1]
                              : c.goldMid,
                          smallBColor: ext.categoryColors.length > base + 2
                              ? ext.categoryColors[base + 2]
                              : c.goldMid,
                          onFeatureTap: base < categories.length
                              ? () => _showSubcategorySheet(
                                  context, categories[base])
                              : null,
                          onSmallATap: base + 1 < categories.length
                              ? () => _showSubcategorySheet(
                                  context, categories[base + 1])
                              : null,
                          onSmallBTap: base + 2 < categories.length
                              ? () => _showSubcategorySheet(
                                  context, categories[base + 2])
                              : null,
                        );
                      },
                      childCount: (categories.length / 3).ceil(),
                    ),
                  ),
                ),

              // ── "Recomienda tu salon" CTA ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _BGRecomendaCTA(
                    onTap: () => context.push('/invite'),
                  ),
                ),
              ),

              // Bottom padding for FAB clearance
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Floating FAB (bottom-right) ─────────────────────────────────
          Positioned(
            right: 20,
            bottom: 40,
            child: BGFab(
              items: [
                BGFabItem(
                  icon: Icons.search_rounded,
                  label: 'Reservar',
                  onTap: () {}, // stays on home
                ),
                BGFabItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Mis Citas',
                  onTap: () => context.push('/my-bookings'),
                ),
                BGFabItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Perfil',
                  onTap: () => context.push('/settings/profile'),
                ),
                BGFabItem(
                  icon: Icons.share_rounded,
                  label: 'Invitar',
                  onTap: () => context.push('/invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BGCarouselItem> _buildCarouselItems(
    BuildContext context,
    List<ServiceCategory> categories,
    BCThemeExtension ext,
    BGColors c,
  ) {
    return categories.take(6).toList().asMap().entries.map((e) {
      final i = e.key;
      final cat = e.value;
      return BGCarouselItem(
        categoryId: cat.id,
        title: cat.nameEs,
        accentColor:
            ext.categoryColors.length > i ? ext.categoryColors[i] : c.goldMid,
        onTap: () => _showSubcategorySheet(context, cat),
      );
    }).toList();
  }

  void _showSubcategorySheet(BuildContext context, ServiceCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubcategorySheet(category: category),
    );
  }
}

// ─── Floating transparent header ─────────────────────────────────────────────

class _BGFloatingHeader extends StatelessWidget {
  final WidgetRef ref;
  const _BGFloatingHeader({required this.ref});

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return Container(
      // Very subtle dark gradient so text is readable over content
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.surface0.withValues(alpha: 0.95),
            c.surface0.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // Gold BC monogram
              BGGoldShimmer(
                child: Text(
                  'BC',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              // Business owner button
              Consumer(
                builder: (context, r, _) {
                  final isBizOwner = r.watch(isBusinessOwnerProvider);
                  return isBizOwner.when(
                    data: (isOwner) => isOwner
                        ? _BGHeaderIcon(
                            icon: Icons.storefront_rounded,
                            onTap: () => context.push('/business'),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(width: 8),
              _BGHeaderIcon(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => context.push('/chat'),
              ),
              const SizedBox(width: 8),
              _BGHeaderIcon(
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BGHeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _BGHeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: c.surface2.withValues(alpha: 0.8),
          border:
              Border.all(color: c.goldMid.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Icon(icon, color: c.goldMid.withValues(alpha: 0.75), size: 20),
      ),
    );
  }
}

// ─── Staggered group: 1 feature card + row of 2 smaller cards ────────────────

class _BGStaggeredGroup extends StatelessWidget {
  final ServiceCategory? feature;
  final ServiceCategory? smallA;
  final ServiceCategory? smallB;
  final Color featureColor;
  final Color smallAColor;
  final Color smallBColor;
  final VoidCallback? onFeatureTap;
  final VoidCallback? onSmallATap;
  final VoidCallback? onSmallBTap;

  const _BGStaggeredGroup({
    required this.feature,
    required this.smallA,
    required this.smallB,
    required this.featureColor,
    required this.smallAColor,
    required this.smallBColor,
    this.onFeatureTap,
    this.onSmallATap,
    this.onSmallBTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Feature card (full-width, 180h)
          if (feature != null)
            _BGFeatureCard(
              category: feature!,
              accentColor: featureColor,
              onTap: onFeatureTap ?? () {},
            ),

          if (feature != null && (smallA != null || smallB != null))
            const SizedBox(height: 12),

          // Row of 2 smaller cards (150h)
          if (smallA != null || smallB != null)
            Row(
              children: [
                if (smallA != null)
                  Expanded(
                    child: _BGSmallCard(
                      category: smallA!,
                      accentColor: smallAColor,
                      onTap: onSmallATap ?? () {},
                    ),
                  ),
                if (smallA != null && smallB != null)
                  const SizedBox(width: 12),
                if (smallB != null)
                  Expanded(
                    child: _BGSmallCard(
                      category: smallB!,
                      accentColor: smallBColor,
                      onTap: onSmallBTap ?? () {},
                    ),
                  )
                else if (smallA != null)
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
        ],
      ),
    );
  }
}

class _BGFeatureCard extends StatefulWidget {
  final ServiceCategory category;
  final Color accentColor;
  final VoidCallback onTap;

  const _BGFeatureCard({
    required this.category,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_BGFeatureCard> createState() => _BGFeatureCardState();
}

class _BGFeatureCardState extends State<_BGFeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.goldMid.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Stack(
            children: [
              // Accent wash
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.category.nameEs,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 2,
                            width: 36,
                            decoration: BoxDecoration(
                              gradient: c.goldGradient,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    getCategoryIcon(
                      variant: ThemeVariant.blackGold,
                      categoryId: widget.category.id,
                      color: widget.accentColor,
                      size: 52,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BGSmallCard extends StatefulWidget {
  final ServiceCategory category;
  final Color accentColor;
  final VoidCallback onTap;

  const _BGSmallCard({
    required this.category,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_BGSmallCard> createState() => _BGSmallCardState();
}

class _BGSmallCardState extends State<_BGSmallCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: c.goldMid.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Stack(
            children: [
              // Subtle corner accent
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accentColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  getCategoryIcon(
                    variant: ThemeVariant.blackGold,
                    categoryId: widget.category.id,
                    color: widget.accentColor,
                    size: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category.nameEs,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── "Recomienda tu salon" CTA card ──────────────────────────────────────────

class _BGRecomendaCTA extends StatefulWidget {
  final VoidCallback onTap;
  const _BGRecomendaCTA({required this.onTap});

  @override
  State<_BGRecomendaCTA> createState() => _BGRecomendaCTAState();
}

class _BGRecomendaCTAState extends State<_BGRecomendaCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [c.goldDark, c.goldMid, const Color(0xFFE8C84A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: c.goldMid.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: c.surface0, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Recomienda tu salon',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.surface0,
                        ),
                      ),
                      Text(
                        'Invita y gana beneficios exclusivos',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: c.surface0.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: c.surface0,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
