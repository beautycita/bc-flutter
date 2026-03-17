import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/business_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/chat_provider.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../services/gesture_exclusion_service.dart';
import '../services/updater_service.dart';
import '../themes/category_icons.dart';
import '../providers/theme_provider.dart';
import '../themes/theme_variant.dart';
import '../widgets/cinematic_question_text.dart';
import '../widgets/video_map_background.dart';
import 'subcategory_sheet.dart';
import 'business/business_shell_screen.dart' show businessTabProvider;
import 'admin/admin_shell_screen.dart' show adminTabProvider;
import '../providers/feature_toggle_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _exclusionSet = false;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showApkUpdateIfNeeded());
  }

  void _showApkUpdateIfNeeded() {
    if (_updateDialogShown) return;
    final updater = UpdaterService.instance;
    if (!updater.apkUpdateAvailable || !mounted) return;
    _updateDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: !updater.apkUpdateRequired,
      builder: (ctx) => _ApkUpdateDialog(
        version: updater.apkUpdateVersion,
        buildNumber: updater.apkRemoteBuild,
        url: updater.apkUpdateUrl,
        required: updater.apkUpdateRequired,
        onDismiss: () {
          updater.dismissApkUpdate();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _updateGestureExclusion(bool isBizOwner, bool isAdmin) {
    if (_exclusionSet) return;
    final mq = MediaQuery.of(context);
    final ratio = mq.devicePixelRatio;
    final screenH = mq.size.height * ratio;
    final screenW = mq.size.width * ratio;
    // Android caps exclusion height at 200dp per edge.
    // Place it in the vertical center where thumb naturally swipes.
    final maxH = 200 * ratio;
    final centerTop = (screenH - maxH) / 2;
    final centerBottom = centerTop + maxH;
    final rects = <ui.Rect>[];
    if (isBizOwner) {
      // Left edge strip — 40dp wide
      rects.add(ui.Rect.fromLTRB(0, centerTop, 40 * ratio, centerBottom));
    }
    if (isAdmin) {
      // Right edge strip — 40dp wide
      rects.add(ui.Rect.fromLTRB(
          screenW - 40 * ratio, centerTop, screenW, centerBottom));
    }
    if (rects.isNotEmpty) {
      GestureExclusionService.setRects(rects);
      _exclusionSet = true;
    }
  }

  @override
  void dispose() {
    if (_exclusionSet) {
      GestureExclusionService.clearRects();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final palette = Theme.of(context).colorScheme;

    final topSectionHeight = screenHeight * 0.34;

    // RP geo-fence: block if outside 300km radius
    final isRp = ref.watch(isRpProvider);
    final rpInZone = ref.watch(rpWithinGeofenceProvider);
    if (isRp.valueOrNull == true && rpInZone.valueOrNull == false) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off_rounded,
                    size: 64, color: palette.error),
                const SizedBox(height: 16),
                Text(
                  'Fuera de zona',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: palette.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Debes estar dentro de 300km de tu zona asignada para usar la app.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: palette.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Maintenance mode gate — non-admin users see a maintenance screen
    final toggles = ref.watch(featureTogglesProvider);
    final isAdminRole = ref.watch(isAdminProvider).valueOrNull ?? false;
    if (toggles.isEnabled('enable_maintenance_mode') && !isAdminRole) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F3FF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.construction_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                const SizedBox(height: AppConstants.paddingLG),
                Text(
                  'En mantenimiento',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Estamos mejorando la app. Vuelve en unos minutos.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: const Color(0xFF757575),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Edge-swipe drawers: business (left) for service providers, admin (right) for admins
    final isBizOwner = ref.watch(isBusinessOwnerProvider);
    final isAdmin = ref.watch(isAdminProvider);

    // Set gesture exclusion rects once roles resolve
    final bizOwnerVal = isBizOwner.valueOrNull ?? false;
    final adminVal = isAdmin.valueOrNull ?? false;
    if ((bizOwnerVal || adminVal) && !_exclusionSet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateGestureExclusion(bizOwnerVal, adminVal);
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Left-edge swipe → Business panel (only for service providers)
      drawer: isBizOwner.when(
        data: (isOwner) => isOwner
            ? _HomeBusinessDrawer(
                onSelectTab: (index) {
                  Navigator.of(context).pop(); // close drawer
                  ref.read(businessTabProvider.notifier).state = index;
                  context.push('/business');
                },
              )
            : null,
        loading: () => null,
        error: (_, _) => null,
      ),
      drawerEdgeDragWidth: 24, // narrow edge zone
      drawerEnableOpenDragGesture: isBizOwner.valueOrNull == true,
      // Right-edge swipe → Admin panel (only for admins/superadmins)
      endDrawer: isAdmin.when(
        data: (admin) => admin
            ? _HomeAdminDrawer(
                onSelectTab: (index) {
                  Navigator.of(context).pop(); // close drawer
                  ref.read(adminTabProvider.notifier).state = index;
                  context.push('/admin');
                },
              )
            : null,
        loading: () => null,
        error: (_, _) => null,
      ),
      endDrawerEnableOpenDragGesture: isAdmin.valueOrNull == true,
      body: Column(
        children: [
          // Header with gradient, decorative shapes, and curved bottom
          SizedBox(
            height: topSectionHeight + 28, // extra for the curve
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient background with hidden color picker easter egg
                _HeroColorPicker(
                  height: topSectionHeight,
                  child: SafeArea(
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
                              // Explore feed button — gated by enable_feed toggle
                              Consumer(
                                builder: (context, ref, _) {
                                  final toggles = ref.watch(featureTogglesProvider);
                                  if (!toggles.isEnabled('enable_feed')) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: AppConstants.paddingSM),
                                    child: _HeaderButton(
                                      icon: Icons.explore_outlined,
                                      onTap: () => context.push('/feed'),
                                    ),
                                  );
                                },
                              ),
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
                              // Invite salon button — gated by enable_salon_invite toggle
                              Consumer(
                                builder: (context, ref, _) {
                                  final toggles = ref.watch(featureTogglesProvider);
                                  if (!toggles.isEnabled('enable_salon_invite')) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: AppConstants.paddingSM),
                                    child: _HeaderButton(
                                      icon: Icons.card_giftcard_rounded,
                                      onTap: () => context.push('/invite'),
                                    ),
                                  );
                                },
                              ),
                              // Chat — gated by enable_salon_chat toggle
                              Consumer(
                                builder: (context, ref, _) {
                                  final toggles = ref.watch(featureTogglesProvider);
                                  if (!toggles.isEnabled('enable_salon_chat')) return const SizedBox.shrink();
                                  final roleAsync = ref.watch(userRoleProvider);
                                  final unreadAsync = ref.watch(totalUnreadProvider);
                                  final unread = unreadAsync.valueOrNull ?? 0;
                                  final role = roleAsync.valueOrNull;
                                  if (role == 'admin' || role == 'superadmin') return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        right: AppConstants.paddingSM),
                                    child: _HeaderButton(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      onTap: () => context.push('/chat'),
                                      badge: unread > 0 ? unread : null,
                                    ),
                                  );
                                },
                              ),
                              _HeaderButton(
                                icon: Icons.settings_outlined,
                                onTap: () => context.push('/settings'),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Brand text — Playfair Display with flowing gradient shimmer
                          _BrandShimmerText(
                            text: AppConstants.appName,
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
                    variant: ref.watch(currentVariantProvider),
                    onTap: () => _showSubcategorySheet(context, category),
                  )
                      .animate()
                      .fadeIn(
                        duration: 400.ms,
                        delay: (80 * index).ms,
                        curve: Curves.easeOut,
                      )
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        duration: 400.ms,
                        delay: (80 * index).ms,
                        curve: Curves.easeOutCubic,
                      )
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1.0, 1.0),
                        duration: 400.ms,
                        delay: (80 * index).ms,
                        curve: Curves.easeOutCubic,
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

/// Hidden color picker easter egg — multi-touch:
/// Long-press activates. First finger left/right = hue (full 360).
/// Second finger up/down = saturation.
/// During drag: writes to lightweight liveHue/liveSat providers (no ThemeData rebuild).
/// On release: commits to theme once.
class _HeroColorPicker extends ConsumerStatefulWidget {
  final double height;
  final Widget child;

  const _HeroColorPicker({required this.height, required this.child});

  @override
  ConsumerState<_HeroColorPicker> createState() => _HeroColorPickerState();
}

class _HeroColorPickerState extends ConsumerState<_HeroColorPicker> {
  bool _active = false;
  int? _huePointer;
  int? _satPointer;
  double _hue = 0;
  double _sat = 0.6;

  Timer? _longPressTimer;
  int? _candidatePointer;
  Offset? _candidateStart;
  static const _longPressDuration = Duration(seconds: 4);
  static const _moveThreshold = 10.0;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _emit() {
    ref.read(liveHueProvider.notifier).state = _hue;
    ref.read(liveSatProvider.notifier).state = _sat;
  }

  void _updateHue(Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _hue = (localPos.dx / box.size.width * 360).clamp(0.0, 360.0);
    _emit();
  }

  void _updateSat(Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _sat = (0.15 + 0.85 * (localPos.dy / box.size.height)).clamp(0.15, 1.0);
    _emit();
  }

  void _finish() {
    // Commit to theme (one-time ThemeData rebuild) and clear live state
    ref.read(themeProvider.notifier).setCustomColorLive(_hue, _sat);
    ref.read(themeProvider.notifier).saveCustomColor();
    ref.read(liveHueProvider.notifier).state = null;
    ref.read(liveSatProvider.notifier).state = null;
    setState(() {
      _active = false;
      _huePointer = null;
      _satPointer = null;
    });
  }

  // Default gradient pair: pink 330° (#FF3399) → blue-violet 270° (#9933FF)
  static const _hueOffset = -60.0; // hue2 = hue1 + offset

  /// Build a gradient color pair from a hue + saturation.
  /// Maintains the 60° offset between the two colors.
  static (Color, Color) _gradientPair(double hue, double sat) {
    final h1 = hue % 360;
    var h2 = (hue + _hueOffset) % 360;
    if (h2 < 0) h2 += 360;
    final c1 = HSLColor.fromAHSL(1.0, h1, sat.clamp(0.5, 1.0), 0.45).toColor();
    final c2 = HSLColor.fromAHSL(1.0, h2, sat.clamp(0.4, 0.9), 0.40).toColor();
    return (c1, c2);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    // During drag, compute gradient pair from live providers (no ThemeData).
    final liveHue = ref.watch(liveHueProvider);
    final liveSat = ref.watch(liveSatProvider);

    // Watch theme state so gradient updates when _load() completes
    ref.watch(themeProvider);

    Color grad1, grad2;
    if (liveHue != null && liveSat != null) {
      // During picker drag, show live preview
      (grad1, grad2) = _gradientPair(liveHue, liveSat);
    } else {
      // Locked home gradient: magenta → indigo (BC's chosen look)
      (grad1, grad2) = _gradientPair(310.0, 0.80);
    }

    return Listener(
      onPointerDown: (e) {
        if (!_active) {
          _candidatePointer = e.pointer;
          _candidateStart = e.localPosition;
          _longPressTimer?.cancel();
          _longPressTimer = Timer(_longPressDuration, () {
            if (_candidatePointer == e.pointer) {
              setState(() => _active = true);
              HapticFeedback.lightImpact();
              _huePointer = e.pointer;
              final notifier = ref.read(themeProvider.notifier);
              _hue = notifier.customHue ?? HSLColor.fromColor(palette.primary).hue;
              _sat = notifier.customSat ?? 0.6;
              _updateHue(e.localPosition);
            }
          });
          return;
        }
        if (_huePointer != null && _satPointer == null) {
          _satPointer = e.pointer;
          HapticFeedback.selectionClick();
          _updateSat(e.localPosition);
        }
      },
      onPointerMove: (e) {
        // Cancel activation if finger moves during the 4s hold
        if (!_active && e.pointer == _candidatePointer && _candidateStart != null) {
          if ((e.localPosition - _candidateStart!).distance > _moveThreshold) {
            _longPressTimer?.cancel();
            _candidatePointer = null;
            _candidateStart = null;
          }
          return;
        }
        if (!_active) return;
        if (e.pointer == _huePointer) {
          _updateHue(e.localPosition);
        } else if (e.pointer == _satPointer) {
          _updateSat(e.localPosition);
        }
      },
      onPointerUp: (e) {
        if (!_active && e.pointer == _candidatePointer) {
          _longPressTimer?.cancel();
          _candidatePointer = null;
          _candidateStart = null;
          return;
        }
        if (e.pointer == _satPointer) {
          _satPointer = null;
        } else if (e.pointer == _huePointer) {
          _finish();
        }
      },
      onPointerCancel: (e) {
        if (e.pointer == _candidatePointer) {
          _longPressTimer?.cancel();
          _candidatePointer = null;
          _candidateStart = null;
        }
        if (e.pointer == _huePointer) {
          _finish();
        } else if (e.pointer == _satPointer) {
          _satPointer = null;
        }
      },
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Looping video background
            const VideoMapBackground(),
            // Color gradient overlay (transparent enough to see video)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    grad1.withValues(alpha: 0.7),
                    Color.lerp(grad1, grad2, 0.5)!.withValues(alpha: 0.7),
                    grad2.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  begin: const Alignment(-0.64, -0.77),
                  end: const Alignment(0.64, 0.77),
                ),
              ),
            ),
            // Content
            widget.child,
          ],
        ),
      ),
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
  final int? badge;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
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
        ),
        if (badge != null && badge! > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badge! > 9 ? '9+' : '$badge',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Brand text with flowing gradient shimmer — replicates the legacy website's
// animate-gradient-flow effect: pink→purple→blue→pink sweeping across text.
class _BrandShimmerText extends StatefulWidget {
  final String text;
  const _BrandShimmerText({required this.text});

  @override
  State<_BrandShimmerText> createState() => _BrandShimmerTextState();
}

class _BrandShimmerTextState extends State<_BrandShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Shift the gradient from 0% → -200% horizontally (background-size: 200%)
        final offset = -2.0 * _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(offset, 0),
              end: Alignment(offset + 2.0, 0),
              colors: const [
                Color(0xFFec4899), // pink-500
                Color(0xFF9333ea), // purple-500
                Color(0xFF3b82f6), // blue-500
                Color(0xFFec4899), // pink-500 (repeat for seamless loop)
              ],
              stops: const [0.0, 0.33, 0.66, 1.0],
              tileMode: TileMode.repeated,
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: Text(
        widget.text,
        style: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white, // ShaderMask replaces this
          letterSpacing: -0.5,
          height: 1.1,
        ),
      ),
    );
  }
}

// Category card — watches liveHueProvider for instant color during drag.
class _CategoryCard extends ConsumerStatefulWidget {
  final ServiceCategory category;
  final int index;
  final ThemeVariant variant;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.index,
    required this.variant,
    required this.onTap,
  });

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.elasticOut,
      ),
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

    // During drag: compute color from live hue (pure math, no ThemeData).
    // Otherwise: use theme category color.
    final liveHue = ref.watch(liveHueProvider);
    Color categoryColor;
    if (liveHue != null) {
      final n = ref.read(themeProvider.notifier);
      final offsets = n.categoryHueOffsets;
      if (widget.index < offsets.length) {
        final hueDelta = liveHue - n.basePrimaryHue;
        var h = (n.basePrimaryHue + offsets[widget.index] + hueDelta) % 360;
        if (h < 0) h += 360;
        categoryColor = HSLColor.fromAHSL(
          1.0, h, n.categorySaturations[widget.index], n.categoryLightnesses[widget.index],
        ).toColor();
      } else {
        categoryColor = palette.primary;
      }
    } else {
      categoryColor = ext.categoryColors.length > widget.index
          ? ext.categoryColors[widget.index]
          : palette.primary;
    }

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
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: () {
          _controller.reverse();
          setState(() => _isPressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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
                    variant: widget.variant,
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

// ---------------------------------------------------------------------------
// Home screen drawers — edge-swipe access to business & admin panels
// ---------------------------------------------------------------------------

class _HomeBusinessDrawer extends StatelessWidget {
  final void Function(int index) onSelectTab;
  const _HomeBusinessDrawer({required this.onSelectTab});

  static const _tabs = <(IconData, String)>[
    (Icons.dashboard_rounded, 'Inicio'),
    (Icons.calendar_month_rounded, 'Calendario'),
    (Icons.design_services_rounded, 'Servicios'),
    (Icons.people_rounded, 'Equipo'),
    (Icons.gavel_rounded, 'Disputas'),
    (Icons.qr_code_rounded, 'QR Cita Express'),
    (Icons.payments_rounded, 'Pagos'),
    (Icons.settings_rounded, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: const Color(0xFFF5F3FF),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.horizontal(right: Radius.circular(AppConstants.radiusLG)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront_rounded,
                      size: 32, color: colors.primary),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Mi Negocio',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  Text(
                    'Portal de Negocio',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.0),
                    colors.primary.withValues(alpha: 0.15),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingSM, vertical: 2),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                        child: ListTile(
                          leading: Icon(
                            _tabs[i].$1,
                            color: const Color(0xFF757575).withValues(alpha: 0.6),
                            size: 22,
                          ),
                          title: Text(
                            _tabs[i].$2,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF212121),
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMD),
                          ),
                          onTap: () => onSelectTab(i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAdminDrawer extends StatelessWidget {
  final void Function(int index) onSelectTab;
  const _HomeAdminDrawer({required this.onSelectTab});

  static const _tabs = <(IconData, String, String)>[
    (Icons.dashboard, 'Dashboard', 'Gestion'),
    (Icons.people, 'Usuarios', 'Gestion'),
    (Icons.assignment, 'Solicitudes', 'Gestion'),
    (Icons.calendar_today, 'Citas', 'Gestion'),
    (Icons.gavel, 'Disputas', 'Gestion'),
    (Icons.store, 'Salones', 'Gestion'),
    (Icons.analytics, 'Analitica', 'Gestion'),
    (Icons.rate_review, 'Resenas', 'Gestion'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Group tabs by section
    final sections = <String, List<int>>{};
    for (var i = 0; i < _tabs.length; i++) {
      sections.putIfAbsent(_tabs[i].$3, () => []).add(i);
    }

    return Drawer(
      backgroundColor: const Color(0xFFF5F3FF),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.horizontal(left: Radius.circular(AppConstants.radiusLG)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings,
                      size: 32, color: colors.primary),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    'Admin Panel',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  Text(
                    'BeautyCita',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.0),
                    colors.primary.withValues(alpha: 0.15),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingSM),
                children: [
                  for (final entry in sections.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: colors.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    for (final i in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingSM, vertical: 2),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMD),
                          child: ListTile(
                            leading: Icon(
                              _tabs[i].$1,
                              color: const Color(0xFF757575).withValues(alpha: 0.6),
                              size: 22,
                            ),
                            title: Text(
                              _tabs[i].$2,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF212121),
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMD),
                            ),
                            onTap: () => onSelectTab(i),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── APK Update Dialog ──

class _ApkUpdateDialog extends StatelessWidget {
  final String version;
  final int buildNumber;
  final String url;
  final bool required;
  final VoidCallback onDismiss;

  const _ApkUpdateDialog({
    required this.version,
    required this.buildNumber,
    required this.url,
    required this.required,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: palette.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nueva version disponible',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        required
            ? 'La version $version (build $buildNumber) es necesaria para continuar usando BeautyCita.'
            : 'La version $version (build $buildNumber) esta disponible con mejoras y correcciones.',
        style: GoogleFonts.nunito(fontSize: 15),
      ),
      actions: [
        if (!required)
          TextButton(
            onPressed: onDismiss,
            child: Text(
              'Mas tarde',
              style: GoogleFonts.nunito(
                color: palette.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ElevatedButton.icon(
          onPressed: () {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.download_rounded),
          label: Text(
            'Actualizar',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
