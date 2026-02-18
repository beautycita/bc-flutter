import 'dart:math' as math;
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
import 'el_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ELHomeScreen — Art Deco Structured Elegance
// Layout: Art Deco Banner → Top Tab Bar (4 tabs) → tab content
// INICIO: Featured horizontal scroll + 3-column grid
// EXPLORAR: Search bar + larger 3-column grid
// CITAS: push /my-bookings
// MAS: Quick links deco grid
// ─────────────────────────────────────────────────────────────────────────────

class ELHomeScreen extends ConsumerStatefulWidget {
  const ELHomeScreen({super.key});

  @override
  ConsumerState<ELHomeScreen> createState() => _ELHomeScreenState();
}

class _ELHomeScreenState extends ConsumerState<ELHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final idx = _tabController.index;
      // CITAS tab → navigate immediately
      if (idx == 2) {
        context.push('/my-bookings');
        // Snap back to INICIO
        Future.microtask(() {
          if (mounted) {
            _tabController.animateTo(0);
            setState(() => _activeTab = 0);
          }
        });
        return;
      }
      setState(() => _activeTab = idx);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSubcategorySheet(BuildContext context, ServiceCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubcategorySheet(category: cat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Art Deco Banner ───────────────────────────────────────────
            Stack(
              children: [
                const ELDecoBanner(),
                // Business owner icon top-right
                Positioned(
                  top: 8,
                  right: 48,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isBizOwner = ref.watch(isBusinessOwnerProvider);
                      return isBizOwner.when(
                        data: (isOwner) => isOwner
                            ? _ELBannerIconButton(
                                icon: Icons.storefront_rounded,
                                onTap: () => context.push('/business'),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ELBannerIconButton(
                    icon: Icons.settings_outlined,
                    onTap: () => context.push('/settings'),
                  ),
                ),
              ],
            ),

            // ── Top Tab Bar ───────────────────────────────────────────────
            _ELTopTabBar(
              controller: _tabController,
              activeIndex: _activeTab,
              tabs: const ['INICIO', 'EXPLORAR', 'CITAS', 'MAS'],
            ),

            // ── Tab Content ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InicioTab(onCategoryTap: _showSubcategorySheet),
                  _ExplorarTab(onCategoryTap: _showSubcategorySheet),
                  // CITAS is handled via listener — show placeholder
                  const _CitasTab(),
                  const _MasTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Banner Icon Button ───────────────────────────────────────────────────────

class _ELBannerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ELBannerIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: c.gold.withValues(alpha: 0.2), width: 1),
        ),
        child: Icon(icon, color: c.gold.withValues(alpha: 0.6), size: 18),
      ),
    );
  }
}

// ─── Top Tab Bar ──────────────────────────────────────────────────────────────

class _ELTopTabBar extends StatelessWidget {
  final TabController controller;
  final int activeIndex;
  final List<String> tabs;

  const _ELTopTabBar({
    required this.controller,
    required this.activeIndex,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return Container(
      height: 44,
      color: c.surface2,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = activeIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.animateTo(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tabs[i],
                    style: GoogleFonts.cinzel(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? c.gold
                          : c.gold.withValues(alpha: 0.35),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isActive) const ELDiamondIndicator(size: 5),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── INICIO Tab ───────────────────────────────────────────────────────────────

class _InicioTab extends ConsumerWidget {
  final void Function(BuildContext, ServiceCategory) onCategoryTap;
  const _InicioTab({required this.onCategoryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ELColors.of(context);
    final categories = ref.watch(categoriesProvider);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // ── Featured horizontal scroll ──────────────────────────────────
        if (categories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ELDecoSectionHeader(label: 'DESTACADOS'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: math.min(categories.length, 6),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final cat = categories[i];
                final color = ext.categoryColors.length > i
                    ? ext.categoryColors[i]
                    : c.emerald;
                return _ELFeaturedCard(
                  category: cat,
                  color: color,
                  onTap: () => onCategoryTap(context, cat),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Deco divider ────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ELGoldAccent(),
        ),

        // ── 3-column grid ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ELDecoSectionHeader(label: 'SERVICIOS'),
        ),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ThreeColumnGrid(
            categories: categories,
            categoryColors: ext.categoryColors,
            onCategoryTap: (cat) => onCategoryTap(context, cat),
          ),
        ),

        const SizedBox(height: 16),

        // ── Invite CTA ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ELInviteCard(),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Featured Card (160 × 200) ────────────────────────────────────────────────

class _ELFeaturedCard extends StatelessWidget {
  final ServiceCategory category;
  final Color color;
  final VoidCallback onTap;

  const _ELFeaturedCard({
    required this.category,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 160,
            height: 200,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.gold.withValues(alpha: 0.3), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getCategoryIcon(
                  variant: ThemeVariant.emeraldLuxe,
                  categoryId: category.id,
                  color: color,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  category.nameEs.toUpperCase(),
                  style: GoogleFonts.cinzel(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Gold accent bar
                Container(
                  width: 32,
                  height: 1.5,
                  color: c.gold.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          // Corner ornaments
          Positioned(top: -1, left: -1, child: ELDecoCorner(size: 10)),
          Positioned(
            top: -1,
            right: -1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: ELDecoCorner(size: 10),
            ),
          ),
          Positioned(
            bottom: -1,
            left: -1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationX(math.pi),
              child: ELDecoCorner(size: 10),
            ),
          ),
          Positioned(
            bottom: -1,
            right: -1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: ELDecoCorner(size: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3-Column Grid ────────────────────────────────────────────────────────────

class _ThreeColumnGrid extends StatelessWidget {
  final List<ServiceCategory> categories;
  final List<Color> categoryColors;
  final void Function(ServiceCategory) onCategoryTap;

  const _ThreeColumnGrid({
    required this.categories,
    required this.categoryColors,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (int i = 0; i < categories.length; i += 3) {
      rows.add(
        Row(
          children: [
            for (int j = i; j < math.min(i + 3, categories.length); j++) ...[
              Expanded(
                child: _ELGridCell(
                  category: categories[j],
                  onTap: () => onCategoryTap(categories[j]),
                ),
              ),
              if (j < i + 2 && j < categories.length - 1)
                const SizedBox(width: 6),
              if (j == categories.length - 1 && j < i + 2)
                ...List.generate(
                  i + 2 - j,
                  (_) => const Expanded(child: SizedBox.shrink()),
                ),
            ],
          ],
        ),
      );
      if (i + 3 < categories.length) rows.add(const SizedBox(height: 6));
    }

    return Column(children: rows);
  }
}

class _ELGridCell extends StatefulWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const _ELGridCell({required this.category, required this.onTap});

  @override
  State<_ELGridCell> createState() => _ELGridCellState();
}

class _ELGridCellState extends State<_ELGridCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Stack(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(
                  color: c.gold.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getCategoryIcon(
                    variant: ThemeVariant.emeraldLuxe,
                    categoryId: widget.category.id,
                    color: c.gold,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      widget.category.nameEs,
                      style: GoogleFonts.raleway(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.text.withValues(alpha: 0.88),
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Deco corner ornaments (small)
            Positioned(top: -1, left: -1, child: ELDecoCorner(size: 6)),
            Positioned(
              top: -1,
              right: -1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: ELDecoCorner(size: 6),
              ),
            ),
            Positioned(
              bottom: -1,
              left: -1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationX(math.pi),
                child: ELDecoCorner(size: 6),
              ),
            ),
            Positioned(
              bottom: -1,
              right: -1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationZ(math.pi),
                child: ELDecoCorner(size: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Invite CTA Card ──────────────────────────────────────────────────────────

class _ELInviteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/invite'),
      child: ELDecoCard(
        cornerLength: 12,
        child: Row(
          children: [
            // Geometric diamond star
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: c.gold.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.star_rounded, color: c.gold, size: 14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recomienda tu salon',
                    style: GoogleFonts.cinzel(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invita y gana beneficios exclusivos',
                    style: GoogleFonts.raleway(
                      fontSize: 11,
                      color: c.emerald.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.gold.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ─── EXPLORAR Tab ─────────────────────────────────────────────────────────────

class _ExplorarTab extends ConsumerStatefulWidget {
  final void Function(BuildContext, ServiceCategory) onCategoryTap;
  const _ExplorarTab({required this.onCategoryTap});

  @override
  ConsumerState<_ExplorarTab> createState() => _ExplorarTabState();
}

class _ExplorarTabState extends ConsumerState<_ExplorarTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    final categories = ref.watch(categoriesProvider);
    final filtered = _query.isEmpty
        ? categories
        : categories
            .where((cat) =>
                cat.nameEs.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Column(
      children: [
        // Search bar with deco styling
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.gold.withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.search, color: c.gold.withValues(alpha: 0.5), size: 20),
                ),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.raleway(
                      color: c.text,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar servicio...',
                      hintStyle: GoogleFonts.raleway(
                        color: c.text.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _query = ''),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.close, color: c.gold.withValues(alpha: 0.4), size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3-column grid with larger cells
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Sin resultados',
                      style: GoogleFonts.raleway(
                        color: c.text.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                _ExplorarGrid(
                  categories: filtered,
                  categoryColors: ext.categoryColors,
                  onCategoryTap: (cat) => widget.onCategoryTap(context, cat),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExplorarGrid extends StatelessWidget {
  final List<ServiceCategory> categories;
  final List<Color> categoryColors;
  final void Function(ServiceCategory) onCategoryTap;

  const _ExplorarGrid({
    required this.categories,
    required this.categoryColors,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < categories.length; i += 3) {
      rows.add(
        Row(
          children: [
            for (int j = i; j < math.min(i + 3, categories.length); j++) ...[
              Expanded(
                child: _ExplorarCell(
                  category: categories[j],
                  onTap: () => onCategoryTap(categories[j]),
                ),
              ),
              if (j < i + 2 && j < categories.length - 1)
                const SizedBox(width: 8),
              if (j == categories.length - 1 && j < i + 2)
                ...List.generate(
                  i + 2 - j,
                  (_) => const Expanded(child: SizedBox.shrink()),
                ),
            ],
          ],
        ),
      );
      if (i + 3 < categories.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

class _ExplorarCell extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;
  const _ExplorarCell({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.gold.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getCategoryIcon(
                  variant: ThemeVariant.emeraldLuxe,
                  categoryId: category.id,
                  color: c.gold,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    category.nameEs.toUpperCase(),
                    style: GoogleFonts.cinzel(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.text.withValues(alpha: 0.85),
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 20, height: 1, color: c.gold.withValues(alpha: 0.5)),
              ],
            ),
          ),
          Positioned(top: -1, left: -1, child: ELDecoCorner(size: 8)),
          Positioned(
            top: -1,
            right: -1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: ELDecoCorner(size: 8),
            ),
          ),
          Positioned(
            bottom: -1,
            left: -1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationX(math.pi),
              child: ELDecoCorner(size: 8),
            ),
          ),
          Positioned(
            bottom: -1,
            right: -1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: ELDecoCorner(size: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CITAS Tab ────────────────────────────────────────────────────────────────

class _CitasTab extends StatelessWidget {
  const _CitasTab();

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ELDiamondIndicator(size: 20),
          const SizedBox(height: 20),
          Text(
            'MIS CITAS',
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.gold,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cargando...',
            style: GoogleFonts.raleway(
              fontSize: 13,
              color: c.text.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MAS Tab ──────────────────────────────────────────────────────────────────

class _MasTab extends StatelessWidget {
  const _MasTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      _MasItem(icon: Icons.person_outline_rounded, label: 'Perfil', route: '/settings/profile'),
      _MasItem(icon: Icons.palette_outlined, label: 'Apariencia', route: '/settings/appearance'),
      _MasItem(icon: Icons.shield_outlined, label: 'Seguridad', route: '/settings/security'),
      _MasItem(icon: Icons.storefront_rounded, label: 'Invitar salon', route: '/invite'),
      _MasItem(icon: Icons.calendar_today_rounded, label: 'Mis citas', route: '/my-bookings'),
      _MasItem(icon: Icons.tune_rounded, label: 'Preferencias', route: '/settings/preferences'),
      _MasItem(icon: Icons.store_rounded, label: 'Registro salon', route: '/registro'),
      _MasItem(icon: Icons.settings_outlined, label: 'Ajustes', route: '/settings'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ELDecoSectionHeader(label: 'ACCESOS RAPIDOS'),
        ),
        // 2-column grid of quick links
        ...List.generate((items.length / 2).ceil(), (row) {
          final a = row * 2;
          final b = a + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: _MasCell(item: items[a])),
                const SizedBox(width: 10),
                if (b < items.length)
                  Expanded(child: _MasCell(item: items[b]))
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _MasItem {
  final IconData icon;
  final String label;
  final String route;
  const _MasItem({required this.icon, required this.label, required this.route});
}

class _MasCell extends StatelessWidget {
  final _MasItem item;
  const _MasCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return GestureDetector(
      onTap: () => context.push(item.route),
      child: ELDecoCard(
        cornerLength: 8,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        child: Row(
          children: [
            Icon(item.icon, color: c.emerald.withValues(alpha: 0.75), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.text.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
