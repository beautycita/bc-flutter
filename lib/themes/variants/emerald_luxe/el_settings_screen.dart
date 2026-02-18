import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import 'el_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ELSettingsScreen — Art Deco Structured Elegance
//
// - Dark green background
// - Art deco section headers with flanking gold lines ─── LABEL ───
// - Profile card with gold border frame and deco corner ornaments
// - Setting tiles with Raleway font and gold chevrons
// - Groups separated by geometric deco dividers (ELGoldAccent)
// - Logout: gold outline button with red text
// ─────────────────────────────────────────────────────────────────────────────

class ELSettingsScreen extends ConsumerWidget {
  const ELSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ELColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _ELSettingsAppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // ── Profile card ───────────────────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/settings/profile'),
            child: ELDecoCard(
              cornerLength: 14,
              child: Row(
                children: [
                  // Avatar with hexagonal-ish clip (using ClipOval for simplicity with deco corners)
                  _ELAvatarFrame(avatarUrl: profile.avatarUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (profile.fullName ?? authState.username ?? 'Usuario').toUpperCase(),
                          style: GoogleFonts.cinzel(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.gold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(width: 16, height: 1, color: c.gold.withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'Editar perfil',
                              style: GoogleFonts.raleway(
                                fontSize: 12,
                                color: c.emerald.withValues(alpha: 0.65),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Double-chevron deco
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_right, color: c.gold.withValues(alpha: 0.25), size: 16),
                      Icon(Icons.chevron_right, color: c.gold.withValues(alpha: 0.5), size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── CUENTA ─────────────────────────────────────────────────────
          ELDecoSectionHeader(label: 'CUENTA'),
          const SizedBox(height: 10),
          _ELSettingTile(
            icon: Icons.tune_rounded,
            label: 'Preferencias',
            onTap: () => context.push('/settings/preferences'),
          ),
          _ELSettingTile(
            icon: Icons.calendar_today_rounded,
            label: 'Mis citas',
            onTap: () => context.push('/my-bookings'),
          ),
          _ELSettingTile(
            icon: Icons.credit_card_rounded,
            label: 'Metodos de pago',
            onTap: () => context.push('/settings/payment-methods'),
          ),

          const SizedBox(height: 8),
          const ELGoldAccent(),

          // ── PERSONALIZACION ────────────────────────────────────────────
          ELDecoSectionHeader(label: 'PERSONALIZACION'),
          const SizedBox(height: 10),
          _ELSettingTile(
            icon: Icons.palette_outlined,
            label: 'Apariencia',
            onTap: () => context.push('/settings/appearance'),
          ),
          _ELSettingTile(
            icon: Icons.shield_outlined,
            label: 'Seguridad y cuenta',
            onTap: () => context.push('/settings/security'),
          ),

          // ── ADMIN ──────────────────────────────────────────────────────
          ref.watch(isAdminProvider).when(
            data: (isAdmin) => isAdmin
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const ELGoldAccent(),
                      ELDecoSectionHeader(label: 'ADMINISTRACION'),
                      const SizedBox(height: 10),
                      _ELSettingTile(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Panel de administracion',
                        onTap: () => context.push('/admin'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),
          const ELGoldAccent(),

          // ── PARA PROFESIONALES ─────────────────────────────────────────
          ELDecoSectionHeader(label: 'PARA PROFESIONALES'),
          const SizedBox(height: 10),
          _ELSettingTile(
            icon: Icons.storefront_rounded,
            label: 'Invitar salon',
            onTap: () => context.push('/invite'),
          ),
          _ELSettingTile(
            icon: Icons.store_rounded,
            label: 'Registra tu salon',
            onTap: () => context.push('/registro'),
          ),

          const SizedBox(height: 32),

          // ── Geometric deco divider before logout ───────────────────────
          _GeometricLogoutDivider(),

          const SizedBox(height: 16),

          // ── Logout: gold outline, red text ─────────────────────────────
          GestureDetector(
            onTap: () => _confirmLogout(context, ref),
            child: Stack(
              children: [
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: c.gold.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.red.shade400, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'CERRAR SESION',
                        style: GoogleFonts.cinzel(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Deco corners on logout button
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
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final c = ELColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mc = ELColors.of(ctx);
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: mc.surface,
            border: Border.all(color: mc.gold.withValues(alpha: 0.3), width: 1),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ELGoldAccent(),
                  const SizedBox(height: 12),
                  Icon(Icons.logout_rounded, size: 40, color: Colors.red.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'CERRAR SESION?',
                    style: GoogleFonts.cinzel(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: mc.text,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                    style: GoogleFonts.raleway(
                      fontSize: 13,
                      color: mc.text.withValues(alpha: 0.45),
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
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: mc.gold.withValues(alpha: 0.35)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.raleway(
                                color: mc.gold,
                                fontWeight: FontWeight.w600,
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
                            height: 48,
                            color: Colors.red.shade700,
                            alignment: Alignment.center,
                            child: Text(
                              'Cerrar sesion',
                              style: GoogleFonts.raleway(
                                color: mc.text,
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

// ─── AppBar ──────────────────────────────────────────────────────────────────

class _ELSettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return Container(
      color: c.surface,
      child: Stack(
        children: [
          // Gold bottom border
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.gold.withValues(alpha: 0.0),
                    c.gold.withValues(alpha: 0.4),
                    c.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Back / close button
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: c.gold.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: c.gold.withValues(alpha: 0.65),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'AJUSTES',
                    style: GoogleFonts.cinzel(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.gold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const Spacer(),
                  // Diamond accent
                  const Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: ELDiamondIndicator(size: 7),
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

// ─── Avatar Frame ─────────────────────────────────────────────────────────────

class _ELAvatarFrame extends StatelessWidget {
  final String? avatarUrl;
  const _ELAvatarFrame({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return Stack(
      children: [
        // Hexagonal clip using ClipPath
        ClipPath(
          clipper: _HexClip(),
          child: Container(
            width: 64,
            height: 64,
            color: c.surface2,
            child: avatarUrl != null
                ? Image.network(avatarUrl!, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.person_outline,
                      color: c.emerald.withValues(alpha: 0.6),
                      size: 30,
                    ),
                  ),
          ),
        ),
        // Gold border overlay (hexagonal)
        SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(painter: _HexBorderPainter()),
        ),
      ],
    );
  }
}

class _HexClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const cut = 12.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(w - cut, 0)
      ..lineTo(w, cut)
      ..lineTo(w, h - cut)
      ..lineTo(w - cut, h)
      ..lineTo(cut, h)
      ..lineTo(0, h - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_HexClip old) => false;
}

class _HexBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = elGold.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const cut = 12.0;
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexBorderPainter old) => false;
}

// ─── Setting Tile ─────────────────────────────────────────────────────────────

class _ELSettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ELSettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: c.gold.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: Row(
            children: [
              // Icon frame
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: c.gold.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(icon, size: 17, color: c.emerald.withValues(alpha: 0.75)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text.withValues(alpha: 0.88),
                  ),
                ),
              ),
              // Gold double-chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_right, color: c.gold.withValues(alpha: 0.2), size: 16),
                  Icon(Icons.chevron_right, color: c.gold.withValues(alpha: 0.45), size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Geometric Logout Divider ─────────────────────────────────────────────────

class _GeometricLogoutDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade700.withValues(alpha: 0.0),
                  Colors.red.shade700.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red.shade700.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade700.withValues(alpha: 0.25),
                  Colors.red.shade700.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
