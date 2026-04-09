import 'package:beautycita/config/app_transitions.dart';
import 'package:beautycita/services/sound_service.dart';
import 'package:beautycita/services/toast_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/business_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/chat_provider.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../services/gesture_exclusion_service.dart';
import '../services/notification_service.dart';
import '../services/updater_service.dart';
import '../themes/category_icons.dart';
import '../themes/theme_variant.dart';
import '../widgets/cinematic_question_text.dart';
import 'onboarding_screen.dart';
import 'subcategory_sheet.dart';
import 'business/business_shell_screen.dart' show businessTabProvider;
import 'admin/admin_shell_screen.dart' show adminTabProvider;
import '../providers/feature_toggle_provider.dart';
import '../providers/review_prompt_provider.dart';
import '../providers/search_history_provider.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/review_prompt_sheet.dart';
import '../services/supabase_client.dart';

/// Fetches the saldo from profiles.saldo for the current user.
final _saldoProvider = FutureProvider<double>((ref) async {
  if (!SupabaseClientService.isInitialized) return 0;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return 0;
  try {
    final data = await SupabaseClientService.client
        .from('profiles')
        .select('saldo')
        .eq('id', userId)
        .single();
    return (data['saldo'] as num?)?.toDouble() ?? 0;
  } catch (_) {
    return 0;
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _exclusionSet = false;
  bool _updateDialogShown = false;
  bool _showPushPrompt = false;
  bool _reviewPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showApkUpdateIfNeeded());
    _checkPushPrompt();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkReviewPrompt());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkOnboarding());
  }

  void _checkReviewPrompt() {
    if (_reviewPromptShown) return;
    // Delay slightly to let providers initialize
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _reviewPromptShown) return;
      final appt = ref.read(unreviewedAppointmentProvider).valueOrNull;
      if (appt != null) {
        _reviewPromptShown = true;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => ReviewPromptSheet(appointment: appt),
        );
      }
    });
  }

  Future<void> _checkOnboarding() async {
    final shown = await OnboardingScreen.hasBeenShown();
    if (!shown && mounted) {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: AppConstants.mediumAnimation,
        ),
      );
    }
  }

  Future<void> _checkPushPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_prompt_shown') == true) return;
    if (mounted) setState(() => _showPushPrompt = true);
  }

  Future<void> _onActivatePush() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_prompt_shown', true);
    try {
      await NotificationService().initialize();
    } catch (_) {}
    if (mounted) setState(() => _showPushPrompt = false);
  }

  Future<void> _dismissPushPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_prompt_shown', true);
    if (mounted) setState(() => _showPushPrompt = false);
  }

  void _showApkUpdateIfNeeded() {
    if (_updateDialogShown) return;
    final updater = UpdaterService.instance;
    if (!updater.apkUpdateAvailable || !mounted) return;
    _updateDialogShown = true;

    showBurstDialog(
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
                // Gradient background with brand gradient overlay
                _HeroGradientBackground(
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

          // Push notification prompt (one-time)
          if (_showPushPrompt)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMD,
                  vertical: AppConstants.paddingSM,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: Text(
                        'Activa notificaciones para no perder tus citas',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    GestureDetector(
                      onTap: _onActivatePush,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                        ),
                        child: Text(
                          'Activar',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9333EA),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _dismissPushPrompt,
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),
            ),

          // Recientes — recent search history chips
          Consumer(
            builder: (context, ref, _) {
              final history = ref.watch(searchHistoryProvider);
              if (history.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMD,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recientes',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final entry = history[index];
                          return ActionChip(
                            label: Text(entry.serviceName),
                            onPressed: () {
                              ref
                                  .read(bookingFlowProvider.notifier)
                                  .selectService(
                                      entry.serviceType, entry.serviceName);
                              context.push('/book');
                            },
                            backgroundColor: palette.primary.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            labelStyle: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.primary,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
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
    final photoCardsEnabled = ref.read(featureTogglesProvider).isEnabled('enable_photo_category_cards');
    final imagePath = _CategoryCardState._categoryImages[category.id];

    if (photoCardsEnabled && imagePath != null) {
      // Immersive full-screen transition with blurred photo backdrop
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ImmersiveSubcategoryPage(
              category: category,
              imagePath: imagePath,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        ),
      );
    } else {
      // Original bottom sheet
      showBurstBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SubcategorySheet(category: category),
      );
    }
  }
}

// ── Immersive subcategory page (photo card flow) ─────────────────────────────

String _getCategoryQuestion(String categoryId) {
  switch (categoryId) {
    case 'nails': return 'Manicure, pedicure o algo mas?';
    case 'hair': return 'Corte, color o tratamiento?';
    case 'facial': return 'Facial, limpieza o tratamiento?';
    case 'lashes_brows': return 'Extensiones, lifting o tinte?';
    case 'body_spa': return 'Masaje, depilacion o tratamiento?';
    case 'makeup': return 'Que tipo de maquillaje?';
    case 'specialized': return 'Que tratamiento necesitas?';
    case 'barberia': return 'Corte, barba o afeitado?';
    default: return 'Que servicio te interesa?';
  }
}

class _ImmersiveSubcategoryPage extends StatelessWidget {
  final ServiceCategory category;
  final String imagePath;

  const _ImmersiveSubcategoryPage({
    required this.category,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred photo backdrop
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
          // Dark overlay for legibility
          Container(color: Colors.black.withValues(alpha: 0.45)),
          // Color tint
          Container(color: color.withValues(alpha: 0.12)),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button + category header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.nameEs,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getCategoryQuestion(category.id),
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 100.ms)
                    .slideY(begin: -0.1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 32),

                // Subcategory cards
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: category.subcategories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final sub = entry.value;
                          return _ImmersiveSubPill(
                            subcategory: sub,
                            categoryColor: color,
                          )
                              .animate()
                              .fadeIn(
                                duration: 350.ms,
                                delay: (200 + 60 * index).ms,
                                curve: Curves.easeOut,
                              )
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                duration: 350.ms,
                                delay: (200 + 60 * index).ms,
                                curve: Curves.easeOutCubic,
                              )
                              .scale(
                                begin: const Offset(0.9, 0.9),
                                end: const Offset(1, 1),
                                duration: 350.ms,
                                delay: (200 + 60 * index).ms,
                                curve: Curves.easeOutCubic,
                              );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveSubPill extends ConsumerStatefulWidget {
  final ServiceSubcategory subcategory;
  final Color categoryColor;

  const _ImmersiveSubPill({
    required this.subcategory,
    required this.categoryColor,
  });

  @override
  ConsumerState<_ImmersiveSubPill> createState() => _ImmersiveSubPillState();
}

class _ImmersiveSubPillState extends ConsumerState<_ImmersiveSubPill> {
  bool _isPressed = false;

  bool _hasItems() {
    final items = widget.subcategory.items;
    return items != null && items.isNotEmpty;
  }

  void _handleTap() {
    if (_hasItems()) {
      showBurstBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ImmersiveItemsSheet(
          subcategory: widget.subcategory,
          categoryColor: widget.categoryColor,
        ),
      );
    } else {
      Navigator.of(context).pop(); // pop immersive page
      final colorValue = widget.categoryColor.toARGB32();
      context.push(
        '/providers?category=${Uri.encodeComponent(widget.subcategory.categoryId)}&subcategory=${Uri.encodeComponent(widget.subcategory.nameEs)}&color=$colorValue',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        _handleTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeIn : Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.subcategory.nameEs,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (_hasItems()) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImmersiveItemsSheet extends ConsumerWidget {
  final ServiceSubcategory subcategory;
  final Color categoryColor;

  const _ImmersiveItemsSheet({
    required this.subcategory,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subcategory.nameEs,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Elige el tipo exacto',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ).animate()
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: -0.05, end: 0, duration: 300.ms),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: (subcategory.items ?? []).length,
                  itemBuilder: (context, index) {
                    final item = (subcategory.items ?? [])[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ImmersiveItemTile(
                        item: item,
                        categoryColor: categoryColor,
                      ),
                    ).animate()
                        .fadeIn(duration: 300.ms, delay: (60 * index).ms)
                        .slideX(begin: 0.06, end: 0, duration: 300.ms, delay: (60 * index).ms);
                  },
                ),
              ),
            ],
          ),
          ),
        ),
        );
      },
    );
  }
}

class _ImmersiveItemTile extends ConsumerStatefulWidget {
  final ServiceItem item;
  final Color categoryColor;

  const _ImmersiveItemTile({required this.item, required this.categoryColor});

  @override
  ConsumerState<_ImmersiveItemTile> createState() => _ImmersiveItemTileState();
}

class _ImmersiveItemTileState extends ConsumerState<_ImmersiveItemTile> {
  bool _isPressed = false;

  void _handleTap() {
    final serviceType = widget.item.serviceType;
    if (serviceType.isEmpty) {
      ToastService.showWarning('Servicio no disponible');
      return;
    }
    Navigator.of(context).pop(); // items sheet
    Navigator.of(context).pop(); // immersive page
    context.push('/book');
    ref.read(bookingFlowProvider.notifier).selectService(serviceType, widget.item.nameEs);
    ref.read(searchHistoryProvider.notifier).addEntry(
      serviceType: widget.item.serviceType,
      serviceName: widget.item.nameEs,
      category: widget.item.subcategoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        SoundService.instance.play(UiSound.tap);
        _handleTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeIn : Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 4, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.item.nameEs,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.35), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hidden color picker easter egg — multi-touch:
/// Hero gradient background — brand gradient (pink→purple→blue) overlay on video.
class _HeroGradientBackground extends StatelessWidget {
  final double height;
  final Widget child;

  const _HeroGradientBackground({required this.height, required this.child});

  // Brand gradient colors
  static const _brandPink = Color(0xFFEC4899);
  static const _brandPurple = Color(0xFF9333EA);
  static const _brandBlue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Brand gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _brandPink.withValues(alpha: 0.7),
                  _brandPurple.withValues(alpha: 0.7),
                  _brandBlue.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: const Alignment(-0.64, -0.77),
                end: const Alignment(0.64, 0.77),
              ),
            ),
          ),
          // Content
          child,
        ],
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _ctrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _ctrl.repeat();
    }
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

// Category card — uses theme category colors.
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

  // Map category IDs to asset images (null = use icon fallback)
  static const _categoryImages = <String, String>{
    'nails': 'assets/categories/unas.jpg',
    'hair': 'assets/categories/cabello.jpg',
    'lashes_brows': 'assets/categories/pestanas.jpg',
    'makeup': 'assets/categories/maquillaje.jpg',
    'facial': 'assets/categories/facial.jpg',
    'body_spa': 'assets/categories/spa_cuerpo.jpg',
    'specialized': 'assets/categories/especializado.jpg',
    'barberia': 'assets/categories/barberia.jpg',
  };

  Widget _buildCardContent(ServiceCategory category, Color categoryColor) {
    final imagePath = _categoryImages[category.id];
    final photoCardsEnabled = ref.watch(featureTogglesProvider).isEnabled('enable_photo_category_cards');

    if (imagePath != null && photoCardsEnabled) {
      // Editorial photo card — heavy color grade for visual unity
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base image
            Image.asset(imagePath, fit: BoxFit.cover),
            // Desaturate: pull most color out
            Container(color: Colors.white.withValues(alpha: 0.35)),
            // Category color tint — this is what unifies them
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    categoryColor.withValues(alpha: 0.25),
                    categoryColor.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
            // Subtle vignette — darkens edges, draws focus to center
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
            // Frosted bottom strip
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            // Category name
            Positioned(
              left: 8, right: 8, bottom: 10,
              child: Text(
                category.nameEs,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: categoryColor,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Animated icon mapping — null means fall back to static icon
    const animatedIcons = <String, String>{
      'nails': 'assets/animated_icons/nails.gif',
      'hair': 'assets/animated_icons/hair.gif',
      'lashes_brows': 'assets/animated_icons/lashes_brows.gif',
      'makeup': 'assets/animated_icons/makeup.gif',
      'facial': 'assets/animated_icons/facial.gif',
      'body_spa': 'assets/animated_icons/body_spa.gif',
      'specialized': 'assets/animated_icons/specialized.gif',
      'barberia': 'assets/animated_icons/barberia.gif',
    };

    final animatedPath = animatedIcons[category.id];

    // Default icon-based card
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
            child: animatedPath != null
                ? Image.asset(
                    animatedPath,
                    width: 40,
                    height: 40,
                    color: categoryColor,
                    colorBlendMode: BlendMode.srcIn,
                  )
                : getCategoryIcon(
                    variant: widget.variant,
                    categoryId: category.id,
                    color: categoryColor,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: 10),
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
          child: _buildCardContent(category, categoryColor),
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
