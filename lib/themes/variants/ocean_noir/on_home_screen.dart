import 'dart:async';
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
import '../../../screens/subcategory_sheet.dart';
import '../../../themes/category_icons.dart';
import '../../../themes/theme_variant.dart';
import 'on_widgets.dart';

class ONHomeScreen extends ConsumerStatefulWidget {
  const ONHomeScreen({super.key});

  @override
  ConsumerState<ONHomeScreen> createState() => _ONHomeScreenState();
}

class _ONHomeScreenState extends ConsumerState<ONHomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Pulsing dot for online indicator
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Clock update
  String _timeStr = '';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    setState(() => _timeStr = '$h:$m');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showSubcategorySheet(BuildContext context, ServiceCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubcategorySheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Scaffold(
      backgroundColor: c.surface0,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Fixed HUD status bar ──────────────────────────────────────
            _buildHudBar(c),

            // Thin cyan separator
            Container(
              height: 0.5,
              color: c.cyan.withValues(alpha: 0.3),
            ),

            // ── 3-Panel PageView ──────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _ServiciosPanel(
                    onSubcategorySheet: (cat) =>
                        _showSubcategorySheet(context, cat),
                  ),
                  _CitasPanel(onGoToServices: () => _goToPage(0)),
                  _PerfilPanel(onGoToSettings: () => context.push('/settings')),
                ],
              ),
            ),

            // Thin separator above indicator
            Container(
              height: 0.5,
              color: c.cyan.withValues(alpha: 0.15),
            ),

            // ── Angular page indicator ────────────────────────────────────
            SafeArea(
              top: false,
              child: Container(
                color: c.surface1,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ONPageIndicator(
                  pageCount: 3,
                  currentPage: _currentPage,
                  labels: const ['SERVICIOS', 'CITAS', 'PERFIL'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudBar(ONColors c) {
    return Container(
      color: c.surface0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left: wordmark
          Text(
            'BEAUTYCITA',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.cyan,
              letterSpacing: 3.0,
            ),
          ),

          const SizedBox(width: 10),

          // Center: pulsing dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.cyan.withValues(alpha: _pulseAnim.value),
                  boxShadow: [
                    BoxShadow(
                      color: c.cyan.withValues(alpha: _pulseAnim.value * 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),

          // Right: version + time
          Text(
            'v1.0  $_timeStr',
            style: GoogleFonts.firaCode(
              fontSize: 10,
              color: c.cyan.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(width: 10),

          // Business icon
          Consumer(
            builder: (context, ref, _) {
              final isBiz = ref.watch(isBusinessOwnerProvider);
              return isBiz.when(
                data: (isOwner) => isOwner
                    ? _HudIconBtn(
                        icon: Icons.storefront_rounded,
                        onTap: () => context.push('/business'),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          _HudIconBtn(
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => context.push('/chat'),
          ),
        ],
      ),
    );
  }
}

// ─── HUD icon button ──────────────────────────────────────────────────────────

class _HudIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HudIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: c.cyan.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: c.cyan.withValues(alpha: 0.6), size: 16),
      ),
    );
  }
}

// ─── Panel 1: SERVICIOS ───────────────────────────────────────────────────────

class _ServiciosPanel extends ConsumerWidget {
  final void Function(ServiceCategory) onSubcategorySheet;
  const _ServiciosPanel({required this.onSubcategorySheet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ONColors.of(context);
    final categories = ref.watch(categoriesProvider);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _PanelHeader(label: 'SERVICIOS DISPONIBLES'),
          ),
        ),

        // 2-column grid of HUD cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= categories.length) return const SizedBox.shrink();
                final cat = categories[i];
                final color = ext.categoryColors.length > i
                    ? ext.categoryColors[i]
                    : c.cyan;
                return _HudCategoryCard(
                  category: cat,
                  color: color,
                  index: i,
                  onTap: () => onSubcategorySheet(cat),
                );
              },
              childCount: categories.length,
            ),
          ),
        ),

        // Recommend CTA
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: _RecomendarCard(),
          ),
        ),
      ],
    );
  }
}

// ─── Panel header with typing cursor ─────────────────────────────────────────

class _PanelHeader extends StatefulWidget {
  final String label;
  const _PanelHeader({required this.label});

  @override
  State<_PanelHeader> createState() => _PanelHeaderState();
}

class _PanelHeaderState extends State<_PanelHeader> {
  bool _cursorOn = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 530),
        (_) => mounted ? setState(() => _cursorOn = !_cursorOn) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Row(
      children: [
        Text(
          '// ',
          style: GoogleFonts.firaCode(
            fontSize: 11,
            color: c.cyan.withValues(alpha: 0.4),
          ),
        ),
        Text(
          widget.label,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c.cyan.withValues(alpha: 0.6),
            letterSpacing: 2.0,
          ),
        ),
        Text(
          _cursorOn ? ' |' : '  ',
          style: GoogleFonts.firaCode(
            fontSize: 12,
            color: c.cyan.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ─── HUD category card ────────────────────────────────────────────────────────

class _HudCategoryCard extends StatefulWidget {
  final ServiceCategory category;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _HudCategoryCard({
    required this.category,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  State<_HudCategoryCard> createState() => _HudCategoryCardState();
}

class _HudCategoryCardState extends State<_HudCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2200 + widget.index * 280),
    )..repeat();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: ClipPath(
          clipper: const ONAngularClipper(clipSize: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(
                color: c.cyanDark,
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                // Animated scan line (cyan at 5%)
                AnimatedBuilder(
                  animation: _scanCtrl,
                  builder: (context, _) {
                    return Positioned(
                      top: _scanCtrl.value * 300,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: c.cyan.withValues(alpha: 0.05),
                      ),
                    );
                  },
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon in angular frame
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.4),
                          ),
                          color: widget.color.withValues(alpha: 0.07),
                        ),
                        alignment: Alignment.center,
                        child: getCategoryIcon(
                          variant: ThemeVariant.oceanNoir,
                          categoryId: widget.category.id,
                          color: widget.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.category.nameEs.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 18,
                        height: 1.5,
                        color: widget.color.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Recommend CTA ────────────────────────────────────────────────────────────

class _RecomendarCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/invite'),
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(
              color: c.cyan.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: c.cyan.withValues(alpha: 0.4)),
                  color: c.cyan.withValues(alpha: 0.07),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.star_rounded,
                    color: c.cyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recomienda tu salon',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Invita y gana beneficios',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: c.cyan.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: c.cyan.withValues(alpha: 0.35), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Panel 2: CITAS ───────────────────────────────────────────────────────────

class _CitasPanel extends StatelessWidget {
  final VoidCallback onGoToServices;
  const _CitasPanel({required this.onGoToServices});

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          _PanelHeader(label: 'RESERVACIONES'),
          const SizedBox(height: 20),

          // Terminal readout — no pending bookings
          ClipPath(
            clipper: const ONAngularClipper(clipSize: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border.all(color: c.cyanDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> STATUS',
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: c.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'NO HAY CITAS PENDIENTES',
                    style: GoogleFonts.rajdhani(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text.withValues(alpha: 0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '// Tu agenda esta vacia',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      color: c.cyan.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pulsing border "RESERVAR AHORA"
          _PulsingBorderCard(
            onTap: onGoToServices,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: c.cyan, size: 20),
                const SizedBox(width: 8),
                Text(
                  'RESERVAR AHORA',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.cyan,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // My bookings link
          GestureDetector(
            onTap: () => context.push('/my-bookings'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '> VER HISTORIAL',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      color: c.cyan.withValues(alpha: 0.4),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing border card ──────────────────────────────────────────────────────

class _PulsingBorderCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PulsingBorderCard({required this.child, required this.onTap});

  @override
  State<_PulsingBorderCard> createState() => _PulsingBorderCardState();
}

class _PulsingBorderCardState extends State<_PulsingBorderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return ClipPath(
            clipper: const ONAngularClipper(clipSize: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.cyan.withValues(alpha: 0.05),
                border: Border.all(
                  color: c.cyan.withValues(alpha: _anim.value),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.cyan.withValues(alpha: _anim.value * 0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ─── Panel 3: PERFIL ──────────────────────────────────────────────────────────

class _PerfilPanel extends ConsumerWidget {
  final VoidCallback onGoToSettings;
  const _PerfilPanel({required this.onGoToSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ONColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 14),
        _PanelHeader(label: 'DATOS DE USUARIO'),
        const SizedBox(height: 16),

        // Profile data terminal format
        ClipPath(
          clipper: const ONAngularClipper(clipSize: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(color: c.cyanDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TerminalRow('NOMBRE',
                    (profile.fullName ?? authState.username ?? 'USUARIO')
                        .toUpperCase()),
                const SizedBox(height: 8),
                _TerminalRow('ESTADO', 'ACTIVO'),
                const SizedBox(height: 8),
                _TerminalRow('MODO', 'USUARIO'),
                if (profile.phone != null) ...[
                  const SizedBox(height: 8),
                  _TerminalRow('TELEFONO',
                      profile.hasVerifiedPhone ? 'VERIFICADO' : 'SIN_VERIFICAR'),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Settings shortcut cards
        _ProfileLink(
          icon: Icons.tune_rounded,
          label: 'PREFERENCIAS',
          code: 'PRF',
          onTap: () => context.push('/settings/preferences'),
        ),
        const SizedBox(height: 8),
        _ProfileLink(
          icon: Icons.calendar_today_rounded,
          label: 'MIS CITAS',
          code: 'CIT',
          onTap: () => context.push('/my-bookings'),
        ),
        const SizedBox(height: 8),
        _ProfileLink(
          icon: Icons.palette_outlined,
          label: 'APARIENCIA',
          code: 'APA',
          onTap: () => context.push('/settings/appearance'),
        ),
        const SizedBox(height: 8),
        _ProfileLink(
          icon: Icons.settings_outlined,
          label: 'AJUSTES',
          code: 'SET',
          onTap: onGoToSettings,
        ),

        const SizedBox(height: 20),

        // Admin link
        ref.watch(isAdminProvider).when(
          data: (isAdmin) => isAdmin
              ? Column(
                  children: [
                    _ProfileLink(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'ADMIN PANEL',
                      code: 'ADM',
                      onTap: () => context.push('/admin'),
                    ),
                    const SizedBox(height: 20),
                  ],
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Logout — red angular card
        GestureDetector(
          onTap: () => _confirmLogout(context, ref),
          child: ClipPath(
            clipper: const ONAngularClipper(clipSize: 14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: c.red.withValues(alpha: 0.08),
                border: Border.all(
                  color: c.red.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '>> CERRAR SESION',
                    style: GoogleFonts.rajdhani(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.red,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogoutSheet(ctx: ctx),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/auth');
    }
  }
}

class _TerminalRow extends StatelessWidget {
  final String key_;
  final String value;
  const _TerminalRow(this.key_, this.value);

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Row(
      children: [
        Text(
          '$key_: ',
          style: GoogleFonts.firaCode(
            fontSize: 11,
            color: c.cyan.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String code;
  final VoidCallback onTap;

  const _ProfileLink({
    required this.icon,
    required this.label,
    required this.code,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(color: c.cyanDark),
          ),
          child: Row(
            children: [
              Text(
                code,
                style: GoogleFonts.firaCode(
                  fontSize: 9,
                  color: c.cyan.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 16, color: c.cyan.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text.withValues(alpha: 0.85),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: c.cyan.withValues(alpha: 0.25), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logout sheet ─────────────────────────────────────────────────────────────

class _LogoutSheet extends StatelessWidget {
  final BuildContext ctx;
  const _LogoutSheet({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface1,
        border: Border.all(color: c.red.withValues(alpha: 0.4)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, color: c.red),
                  const SizedBox(width: 8),
                  Text(
                    '> CONFIRMACION_REQUERIDA',
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: c.red.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Icon(Icons.logout_rounded, size: 44, color: c.red),
              const SizedBox(height: 10),
              Text(
                'CERRAR SESION?',
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: ClipPath(
                        clipper: const ONAngularClipper(clipSize: 8),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: c.cyan.withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CANCELAR',
                            style: GoogleFonts.rajdhani(
                              color: c.cyan,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: ClipPath(
                        clipper: const ONAngularClipper(clipSize: 8),
                        child: Container(
                          height: 48,
                          color: c.red,
                          alignment: Alignment.center,
                          child: Text(
                            'CERRAR',
                            style: GoogleFonts.rajdhani(
                              color: c.text,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
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
