import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../config/theme_extension.dart';
import '../../../config/constants.dart';
import '../../../screens/subcategory_sheet.dart';
import '../../../themes/category_icons.dart';
import '../../../themes/theme_variant.dart';
import '../../../main.dart' show supabaseReady;
import 'cb_widgets.dart';

// ─── Time-based greeting ───────────────────────────────────────────────────────
String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Buenos dias';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

// ─── CBHomeScreen ──────────────────────────────────────────────────────────────
class CBHomeScreen extends ConsumerStatefulWidget {
  const CBHomeScreen({super.key});

  @override
  ConsumerState<CBHomeScreen> createState() => _CBHomeScreenState();
}

class _CBHomeScreenState extends ConsumerState<CBHomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController =
      PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSubcategorySheet(ServiceCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubcategorySheet(category: category),
    );
  }

  void _showQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) => _CBQuickMenuSheet(
        onProfileTap: () {
          Navigator.pop(ctx);
          context.push('/settings/profile');
        },
        onAppearanceTap: () {
          Navigator.pop(ctx);
          context.push('/settings/appearance');
        },
        onInviteTap: () {
          Navigator.pop(ctx);
          context.push('/invite');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    final categories = ref.watch(categoriesProvider);

    // Build pages: real categories + "Recomienda" CTA page
    final pages = <_PageData>[
      for (final cat in categories)
        _PageData(category: cat, isInvite: false),
      const _PageData(category: null, isInvite: true),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // ── Fixed top section ──────────────────────────────────────
                _CBZenHeader(
                  onBusinessTap: () => context.push('/business'),
                  onChatTap: () => context.push('/chat'),
                  onSettingsTap: () => context.push('/settings'),
                ),

                // ── Vertical snap PageView ─────────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        physics: const BouncingScrollPhysics(),
                        itemCount: pages.isEmpty ? 1 : pages.length,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemBuilder: (context, i) {
                          if (pages.isEmpty) {
                            return const _CBCategoryPage(
                              category: null,
                              isInvite: false,
                              onTap: null,
                            );
                          }
                          final page = pages[i];
                          return _CBCategoryPage(
                            category: page.category,
                            isInvite: page.isInvite,
                            onTap: page.isInvite
                                ? () => context.push('/invite')
                                : page.category != null
                                    ? () =>
                                        _showSubcategorySheet(page.category!)
                                    : null,
                          );
                        },
                      ),

                      // Vertical page dots on right edge
                      if (pages.isNotEmpty)
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _CBVerticalDots(
                              count: pages.length,
                              current: _currentPage,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Space for floating pill
                const SizedBox(height: 72),
              ],
            ),

            // ── Floating bottom pill ───────────────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: CBFloatingPill(
                  myBookingsActive: false,
                  onMyBookingsTap: () => context.push('/my-bookings'),
                  onSwipeUp: _showQuickMenu,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page data model ───────────────────────────────────────────────────────────
class _PageData {
  final ServiceCategory? category;
  final bool isInvite;
  const _PageData({required this.category, required this.isInvite});
}

// ─── CBZenHeader ───────────────────────────────────────────────────────────────
class _CBZenHeader extends ConsumerWidget {
  final VoidCallback onBusinessTap;
  final VoidCallback onChatTap;
  final VoidCallback onSettingsTap;

  const _CBZenHeader({
    required this.onBusinessTap,
    required this.onChatTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CBColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Column(
        children: [
          // Time greeting
          Text(
            _greeting(),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: c.pink.withValues(alpha: 0.50),
            ),
          ),

          const SizedBox(height: 2),

          // Brand name
          Text(
            'BeautyCita',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 12,
              letterSpacing: 4.0,
              color: c.pink.withValues(alpha: 0.30),
            ),
          ),

          const SizedBox(height: 12),

          // Icon row — very subtle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ref.watch(isBusinessOwnerProvider).when(
                    data: (isOwner) => isOwner
                        ? _CBTinyIcon(
                            icon: Icons.storefront_outlined,
                            onTap: onBusinessTap,
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
              _CBTinyIcon(icon: Icons.chat_bubble_outline, onTap: onChatTap),
              const SizedBox(width: 4),
              _CBTinyIcon(icon: Icons.tune, onTap: onSettingsTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _CBTinyIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CBTinyIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(icon, size: 18, color: c.pink.withValues(alpha: 0.25)),
      ),
    );
  }
}

// ─── CBCategoryPage ────────────────────────────────────────────────────────────
/// A single full-height category page in the vertical PageView.
class _CBCategoryPage extends StatefulWidget {
  final ServiceCategory? category;
  final bool isInvite;
  final VoidCallback? onTap;

  const _CBCategoryPage({
    required this.category,
    required this.isInvite,
    required this.onTap,
  });

  @override
  State<_CBCategoryPage> createState() => _CBCategoryPageState();
}

class _CBCategoryPageState extends State<_CBCategoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatY;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    final availableHeight = MediaQuery.of(context).size.height * 0.70;

    return Padding(
      // Top/bottom padding creates breathing room between pages
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 130),
          child: Container(
            height: availableHeight,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: c.pink.withValues(alpha: 0.03),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: widget.isInvite
                ? _buildInvitePage(c)
                : _buildCategoryPage(c),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPage(CBColors c) {
    final cat = widget.category;
    if (cat == null) {
      return const Center(child: CBLoadingDots());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Floating emoji
        AnimatedBuilder(
          animation: _floatY,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, _floatY.value),
              child: getCategoryIcon(
                variant: ThemeVariant.cherryBlossom,
                categoryId: cat.id,
                color: cat.color,
                size: 64,
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Category name
        Text(
          cat.nameEs,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: c.text,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Watercolor accent line
        const CBAccentLine(width: 40, height: 2),

        const SizedBox(height: 8),

        // Explorar label
        Text(
          'Explorar',
          style: GoogleFonts.nunitoSans(
            fontSize: 14,
            color: c.pink.withValues(alpha: 0.60),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInvitePage(CBColors c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Petal motif
        Text(
          '\u{1F338}',
          style: const TextStyle(fontSize: 52),
        ),

        const SizedBox(height: 24),

        Text(
          'Recomienda\ntu salon',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: c.text,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        const CBAccentLine(width: 40, height: 2),

        const SizedBox(height: 8),

        Text(
          'Invita y gana beneficios',
          style: GoogleFonts.nunitoSans(
            fontSize: 14,
            color: c.pink.withValues(alpha: 0.55),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Vertical page dot indicator ──────────────────────────────────────────────
class _CBVerticalDots extends StatelessWidget {
  final int count;
  final int current;

  const _CBVerticalDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(vertical: 3),
          width: 4,
          height: isActive ? 12 : 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isActive
                ? c.pink.withValues(alpha: 0.70)
                : c.pink.withValues(alpha: 0.20),
          ),
        );
      }),
    );
  }
}

// ─── Quick menu bottom sheet ───────────────────────────────────────────────────
class _CBQuickMenuSheet extends StatelessWidget {
  final VoidCallback onProfileTap;
  final VoidCallback onAppearanceTap;
  final VoidCallback onInviteTap;

  const _CBQuickMenuSheet({
    required this.onProfileTap,
    required this.onAppearanceTap,
    required this.onInviteTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: c.pink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 32,
            height: 3,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: c.pink.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          _QMenuTile(
            label: 'Perfil',
            icon: Icons.person_outline,
            onTap: onProfileTap,
          ),
          const CBPetalDivider(),
          _QMenuTile(
            label: 'Apariencia',
            icon: Icons.palette_outlined,
            onTap: onAppearanceTap,
          ),
          const CBPetalDivider(),
          _QMenuTile(
            label: 'Invitar salon',
            icon: Icons.favorite_border,
            onTap: onInviteTap,
          ),
        ],
      ),
    );
  }
}

class _QMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QMenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.pink.withValues(alpha: 0.55)),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.text.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
