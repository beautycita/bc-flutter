import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import 'mo_widgets.dart';

// ─── _buildOrganicPath (local helper, mirrors mo_widgets.dart implementation) ─
Path _buildOrganicPath(Size size, int seed) {
  final rng = math.Random(seed * 31 + 7);
  final w = size.width;
  final h = size.height;
  final tlR = 20.0 + rng.nextDouble() * 24;
  final trR = 18.0 + rng.nextDouble() * 28;
  final brR = 22.0 + rng.nextDouble() * 20;
  final blR = 16.0 + rng.nextDouble() * 26;
  final topBulge = (rng.nextDouble() - 0.35) * 12;
  final rightBulge = (rng.nextDouble() - 0.35) * 10;
  final bottomBulge = (rng.nextDouble() - 0.35) * 14;
  final leftBulge = (rng.nextDouble() - 0.35) * 10;

  final path = Path();
  path.moveTo(tlR, 0);
  path.cubicTo(w * 0.33, -topBulge, w * 0.67, -topBulge, w - trR, 0);
  path.quadraticBezierTo(w, 0, w, trR);
  path.cubicTo(
      w + rightBulge, h * 0.33, w + rightBulge, h * 0.67, w, h - brR);
  path.quadraticBezierTo(w, h, w - brR, h);
  path.cubicTo(
      w * 0.67, h + bottomBulge, w * 0.33, h + bottomBulge, blR, h);
  path.quadraticBezierTo(0, h, 0, h - blR);
  path.cubicTo(-leftBulge, h * 0.67, -leftBulge, h * 0.33, 0, tlR);
  path.quadraticBezierTo(0, 0, tlR, 0);
  path.close();
  return path;
}

// ─── Settings screen ──────────────────────────────────────────────────────────
class MOSettingsScreen extends ConsumerStatefulWidget {
  const MOSettingsScreen({super.key});

  @override
  ConsumerState<MOSettingsScreen> createState() => _MOSettingsScreenState();
}

class _MOSettingsScreenState extends ConsumerState<MOSettingsScreen>
    with TickerProviderStateMixin {
  bool _prefExpanded = true;
  bool _proExpanded = false;
  bool _adminExpanded = false;

  late AnimationController _prefCtrl;
  late AnimationController _proCtrl;
  late AnimationController _adminCtrl;

  @override
  void initState() {
    super.initState();
    _prefCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );
    _proCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 0.0,
    );
    _adminCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _prefCtrl.dispose();
    _proCtrl.dispose();
    _adminCtrl.dispose();
    super.dispose();
  }

  void _togglePref() {
    setState(() => _prefExpanded = !_prefExpanded);
    _prefExpanded ? _prefCtrl.forward() : _prefCtrl.reverse();
  }

  void _togglePro() {
    setState(() => _proExpanded = !_proExpanded);
    _proExpanded ? _proCtrl.forward() : _proCtrl.reverse();
  }

  void _toggleAdmin() {
    setState(() => _adminExpanded = !_adminExpanded);
    _adminExpanded ? _adminCtrl.forward() : _adminCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(
        children: [
          // Floating particles background
          const MOFloatingParticles(count: 12, seedOffset: 200),

          // Ambient glow — top left
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.orchidPurple.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.card,
                            border: Border.all(
                              color: c.orchidDeep.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: c.orchidPurple.withValues(alpha: 0.8),
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            c.orchidGradient.createShader(bounds),
                        child: Text(
                          'Ajustes',
                          style: GoogleFonts.quicksand(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Scrollable body ──────────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Organic profile card
                      _MOOrganicProfileCard(
                        displayName: profile.fullName ??
                            authState.username ??
                            'Usuario',
                        avatarUrl: profile.avatarUrl,
                        onTap: () => context.push('/settings/profile'),
                      ),

                      const SizedBox(height: 24),

                      // Preferences section
                      _SectionHeader(
                        label: 'PREFERENCIAS',
                        expanded: _prefExpanded,
                        onTap: _togglePref,
                      ),
                      const SizedBox(height: 8),
                      _SpringExpandSection(
                        controller: _prefCtrl,
                        children: [
                          _OrganicTile(
                            icon: Icons.tune_rounded,
                            label: 'Preferencias',
                            onTap: () =>
                                context.push('/settings/preferences'),
                          ),
                          _OrganicTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Mis citas',
                            onTap: () => context.push('/my-bookings'),
                          ),
                          _OrganicTile(
                            icon: Icons.credit_card_rounded,
                            label: 'Metodos de pago',
                            onTap: () =>
                                context.push('/settings/payment-methods'),
                          ),
                          _OrganicTile(
                            icon: Icons.palette_outlined,
                            label: 'Apariencia',
                            onTap: () =>
                                context.push('/settings/appearance'),
                          ),
                          _OrganicTile(
                            icon: Icons.shield_outlined,
                            label: 'Seguridad y cuenta',
                            isLast: true,
                            onTap: () => context.push('/settings/security'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Para profesionales
                      _SectionHeader(
                        label: 'PARA PROFESIONALES',
                        expanded: _proExpanded,
                        onTap: _togglePro,
                      ),
                      const SizedBox(height: 8),
                      _SpringExpandSection(
                        controller: _proCtrl,
                        children: [
                          _OrganicTile(
                            icon: Icons.store_rounded,
                            label: 'Registra tu salon',
                            isLast: true,
                            onTap: () => context.push('/registro'),
                          ),
                        ],
                      ),

                      // Admin (conditional)
                      ref.watch(isAdminProvider).when(
                            data: (isAdmin) => isAdmin
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      _SectionHeader(
                                        label: 'ADMINISTRACION',
                                        expanded: _adminExpanded,
                                        onTap: _toggleAdmin,
                                        gradient: true,
                                      ),
                                      const SizedBox(height: 8),
                                      _SpringExpandSection(
                                        controller: _adminCtrl,
                                        children: [
                                          _OrganicTile(
                                            icon: Icons
                                                .admin_panel_settings_rounded,
                                            label:
                                                'Panel de administracion',
                                            isLast: true,
                                            onTap: () =>
                                                context.push('/admin'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),

                      const SizedBox(height: 36),

                      // Logout
                      _LogoutButton(
                        onTap: () => _confirmLogout(context, ref),
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

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final c = MOColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipPath(
          clipper: _RoundedTopClipper(),
          child: Container(
            color: c.card,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: c.orchidGradient,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.10),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(Icons.logout_rounded,
                        color: Colors.red.shade400, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cerrar sesion?',
                    style: GoogleFonts.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.text.withValues(alpha: 0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: c.orchidDeep, width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.quicksand(
                                color: c.orchidPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFB71C1C),
                                  Color(0xFFE53935),
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cerrar sesion',
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
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
      },
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/auth');
    }
  }
}

// ─── Organic profile card ──────────────────────────────────────────────────────
class _MOOrganicProfileCard extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _MOOrganicProfileCard({
    required this.displayName,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _OrganicProfilePainter(cardColor: c.card, borderColor: c.orchidDeep, glowColor: c.orchidPurple),
        child: ClipPath(
          clipper: _ProfileOrganicClipper(),
          child: Container(
            color: c.card,
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                // Avatar with orchid gradient ring
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: c.orchidGradient,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: c.surface,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? ShaderMask(
                            shaderCallback: (b) =>
                                c.orchidGradient.createShader(b),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 30,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            c.orchidGradient.createShader(b),
                        child: Text(
                          displayName,
                          style: GoogleFonts.quicksand(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Editar perfil',
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.orchidPurple.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: c.orchidPurple.withValues(alpha: 0.40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOrganicClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _buildOrganicPath(size, 7);

  @override
  bool shouldReclip(_ProfileOrganicClipper _) => false;
}

class _OrganicProfilePainter extends CustomPainter {
  final Color cardColor;
  final Color borderColor;
  final Color glowColor;

  _OrganicProfilePainter({
    required this.cardColor,
    required this.borderColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildOrganicPath(size, 7);
    canvas.drawPath(path, Paint()..color = cardColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_OrganicProfilePainter old) =>
      old.cardColor != cardColor || old.borderColor != borderColor;
}

// ─── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final bool gradient;

  const _SectionHeader({
    required this.label,
    required this.expanded,
    required this.onTap,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          gradient
              ? ShaderMask(
                  shaderCallback: (b) => c.orchidGradient.createShader(b),
                  child: Text(
                    label,
                    style: GoogleFonts.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: c.orchidPurple.withValues(alpha: 0.55),
                  ),
                ),
          const Spacer(),
          AnimatedRotation(
            turns: expanded ? 0 : -0.25,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: Icon(
              Icons.expand_more_rounded,
              color: c.orchidPurple.withValues(alpha: 0.45),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spring-expand section ────────────────────────────────────────────────────
class _SpringExpandSection extends StatelessWidget {
  final AnimationController controller;
  final List<Widget> children;

  const _SpringExpandSection({
    required this.controller,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final curve = CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOutCubic,
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: curve.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: c.orchidDeep.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ─── Organic tile ──────────────────────────────────────────────────────────────
class _OrganicTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _OrganicTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: c.orchidPink.withValues(alpha: 0.08),
            highlightColor: c.orchidPurple.withValues(alpha: 0.05),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: c.orchidDeep.withValues(alpha: 0.5),
                    ),
                    child: ShaderMask(
                      shaderCallback: (b) => c.orchidGradient.createShader(b),
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.text.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: c.orchidPurple.withValues(alpha: 0.30),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 0,
            thickness: 0.5,
            color: c.orchidDeep.withValues(alpha: 0.5),
            indent: 68,
          ),
      ],
    );
  }
}

// ─── Logout button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                c.orchidPurple.withValues(alpha: 0.12),
                Colors.red.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [c.orchidPurple, Colors.red.shade400],
                ).createShader(bounds),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [c.orchidPurple, Colors.red.shade400],
                ).createShader(bounds),
                child: Text(
                  'Cerrar sesion',
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Rounded top clipper ───────────────────────────────────────────────────────
class _RoundedTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 32.0;
    final path = Path();
    path.moveTo(r, 0);
    path.quadraticBezierTo(0, 0, 0, r);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, r);
    path.quadraticBezierTo(size.width, 0, size.width - r, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_RoundedTopClipper _) => false;
}
