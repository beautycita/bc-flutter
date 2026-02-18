import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/business_provider.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../themes/category_icons.dart';
import '../themes/theme_variant.dart';
import '../widgets/animated_city_map.dart';
import '../widgets/cinematic_question_text.dart';
import 'subcategory_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final palette = Theme.of(context).colorScheme;

    final topSectionHeight = screenHeight * 0.34;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header with gradient, decorative shapes, and curved bottom
          SizedBox(
            height: topSectionHeight + 28, // extra for the curve
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient background with decorative circles
                Container(
                  height: topSectionHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE91E63), palette.primary, Color(0xFFAD1457)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Animated city map background
                      const Positioned.fill(
                        child: AnimatedCityMap(),
                      ),

                      // Safe area content
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.screenPaddingHorizontal,
                          ),
                          child: Column(
                            children: [
                              // Top row with nav buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Mi Negocio button — only visible for business owners
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final isBizOwner = ref.watch(isBusinessOwnerProvider);
                                      return isBizOwner.when(
                                        data: (isOwner) => isOwner
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    right: AppConstants.paddingSM),
                                                child: _HeaderButton(
                                                  icon: Icons.storefront_rounded,
                                                  onTap: () => context.push('/business'),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                        loading: () => const SizedBox.shrink(),
                                        error: (e, st) => const SizedBox.shrink(),
                                      );
                                    },
                                  ),
                                  _HeaderButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    onTap: () => context.push('/chat'),
                                  ),
                                  const SizedBox(width: AppConstants.paddingSM),
                                  _HeaderButton(
                                    icon: Icons.settings_outlined,
                                    onTap: () => context.push('/settings'),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Brand text (subtle)
                              Text(
                                AppConstants.appName,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: AppConstants.paddingSM),
                              // Cinematic question text
                              CinematicQuestionText(
                                text: 'Que buscas hoy?',
                                primaryColor: Colors.white,
                                accentColor: palette.secondary,
                                fontSize: 30,
                              ),
                              const SizedBox(height: 40), // space before curve
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Curved bottom edge
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(screenWidth, 28),
                    painter: _CurvePainter(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Gradient fade from scaffold bg to transparent
          Container(
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),

          // Category Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
              ),
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 0, bottom: 16),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryCard(
                    category: category,
                    index: index,
                    onTap: () => _showSubcategorySheet(context, category),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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

// Curved wave painter for the header bottom edge
class _CurvePainter extends CustomPainter {
  final Color color;
  const _CurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.6,
        0,
        size.height * 0.6,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Frosted glass header buttons
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// Redesigned category card with colored icon circle and better depth
class _CategoryCard extends StatefulWidget {
  final ServiceCategory category;
  final int index;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.index,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final category = widget.category;
    final palette = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final categoryColor = ext.categoryColors.length > widget.index
        ? ext.categoryColors[widget.index]
        : palette.primary;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () {
          _controller.reverse();
          setState(() => _isPressed = false);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.12),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: _isPressed ? 0.15 : 0.10),
                blurRadius: _isPressed ? 8 : 16,
                offset: Offset(0, _isPressed ? 2 : 6),
                spreadRadius: _isPressed ? -2 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Colored circle behind emoji
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      categoryColor.withValues(alpha: 0.12),
                      categoryColor.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: getCategoryIcon(
                    variant: ThemeVariant.roseGold,
                    categoryId: category.id,
                    color: categoryColor,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Category name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  category.nameEs,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: categoryColor.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
