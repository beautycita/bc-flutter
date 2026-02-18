import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import 'gl_widgets.dart';

class GLSettingsScreen extends ConsumerStatefulWidget {
  const GLSettingsScreen({super.key});

  @override
  ConsumerState<GLSettingsScreen> createState() => _GLSettingsScreenState();
}

class _GLSettingsScreenState extends ConsumerState<GLSettingsScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardSlides;
  late List<Animation<double>> _cardFades;

  // Number of animated sections: profile + main group + pro + admin (conditional) + logout
  static const _cardCount = 5;

  @override
  void initState() {
    super.initState();

    _cardControllers = List.generate(
      _cardCount,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      ),
    );

    _cardSlides = _cardControllers.map((ctrl) {
      return Tween(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));
    }).toList();

    _cardFades = _cardControllers.map((ctrl) {
      return Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
      );
    }).toList();

    // Staggered entry: each card slides in from right, 80ms apart
    for (int i = 0; i < _cardCount; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final ctrl in _cardControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    if (index >= _cardCount) return child;
    return SlideTransition(
      position: _cardSlides[index],
      child: FadeTransition(
        opacity: _cardFades[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: c.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen aurora background (same animated gradient)
          const GlAuroraBackground(child: SizedBox.expand()),

          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.12),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: c.text.withValues(alpha: 0.8),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            c.neonGradient.createShader(bounds),
                        child: Text(
                          'Ajustes',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 0 — Profile card
                      _animated(
                        0,
                        _ProfileCard(authState: authState, profile: profile),
                      ),

                      const SizedBox(height: 20),

                      // 1 — Main settings group
                      _animated(
                        1,
                        _SettingsSection(
                          label: 'CUENTA',
                          tiles: [
                            _SettingTile(
                              icon: Icons.tune_rounded,
                              label: 'Preferencias',
                              accent: c.neonPurple,
                              onTap: () =>
                                  context.push('/settings/preferences'),
                            ),
                            _SettingTile(
                              icon: Icons.calendar_today_rounded,
                              label: 'Mis citas',
                              accent: c.neonCyan,
                              onTap: () => context.push('/my-bookings'),
                            ),
                            _SettingTile(
                              icon: Icons.credit_card_rounded,
                              label: 'Metodos de pago',
                              accent: c.neonPink,
                              onTap: () => context
                                  .push('/settings/payment-methods'),
                            ),
                            _SettingTile(
                              icon: Icons.palette_outlined,
                              label: 'Apariencia',
                              accent: c.violet,
                              onTap: () =>
                                  context.push('/settings/appearance'),
                            ),
                            _SettingTile(
                              icon: Icons.shield_outlined,
                              label: 'Seguridad y cuenta',
                              accent: c.indigo,
                              onTap: () =>
                                  context.push('/settings/security'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2 — Pro section
                      _animated(
                        2,
                        _SettingsSection(
                          label: 'PARA PROFESIONALES',
                          tiles: [
                            _SettingTile(
                              icon: Icons.store_rounded,
                              label: 'Registra tu salon',
                              accent: c.teal,
                              onTap: () => context.push('/registro'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3 — Admin section (conditional)
                      ref.watch(isAdminProvider).when(
                        data: (isAdmin) => isAdmin
                            ? _animated(
                                3,
                                _SettingsSection(
                                  label: 'ADMINISTRACION',
                                  tiles: [
                                    _SettingTile(
                                      icon: Icons
                                          .admin_panel_settings_rounded,
                                      label: 'Panel de administracion',
                                      accent: c.amber,
                                      onTap: () =>
                                          context.push('/admin'),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 28),

                      // 4 — Logout
                      _animated(
                        4,
                        _LogoutButton(
                          onTap: () => _confirmLogout(context, ref),
                        ),
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
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final c = GlColors.of(ctx);
        return Container(
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: c.neonGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Icon(
                        Icons.logout_rounded,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Cerrar sesion?',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: c.text.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx, false),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.05),
                                      borderRadius:
                                          BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        width: 0.8,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Cancelar',
                                      style: GoogleFonts.inter(
                                        color: c.text
                                            .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w600,
                                      ),
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
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Cerrar sesion',
                                  style: GoogleFonts.inter(
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

// ─── Profile Card ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AuthState authState;
  final ProfileState profile;

  const _ProfileCard({required this.authState, required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/settings/profile'),
      child: IridescentBorder(
        borderRadius: 22,
        borderWidth: 1.2,
        duration: const Duration(seconds: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20.8),
              ),
              child: Row(
                children: [
                  // Avatar with neon gradient ring
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: c.neonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: c.neonPink.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.bgDeep,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: c.bgMid,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Icon(
                                Icons.person_outline,
                                color: c.text.withValues(alpha: 0.5),
                                size: 30,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              c.neonGradient.createShader(bounds),
                          child: Text(
                            profile.fullName ??
                                authState.username ??
                                'Usuario',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Editar perfil',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: c.text.withValues(alpha: 0.40),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: c.text.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Settings Section ─────────────────────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final String label;
  final List<_SettingTile> tiles;

  const _SettingsSection({required this.label, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: c.text.withValues(alpha: 0.35),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    tiles[i],
                    if (i < tiles.length - 1)
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Setting Tile ─────────────────────────────────────────────────────────────
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = glNeonPink,
  });

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              // Frosted icon container with neon accent
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                        width: 0.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 18, color: accent),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text.withValues(alpha: 0.90),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: c.text.withValues(alpha: 0.22),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logout Button ────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.red.shade700.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cerrar sesion',
                  style: GoogleFonts.inter(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
