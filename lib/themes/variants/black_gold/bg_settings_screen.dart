import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import 'bg_widgets.dart';

class BGSettingsScreen extends ConsumerStatefulWidget {
  const BGSettingsScreen({super.key});

  @override
  ConsumerState<BGSettingsScreen> createState() => _BGSettingsScreenState();
}

class _BGSettingsScreenState extends ConsumerState<BGSettingsScreen>
    with SingleTickerProviderStateMixin {
  // Staggered animation for tiles
  late AnimationController _staggerController;
  final List<Animation<double>> _tileAnimations = [];

  // Collapsible section state
  bool _accountExpanded = true;
  bool _proExpanded = false;

  // Total number of animated tiles (adjust if adding more)
  static const int _tileCount = 8;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Build staggered slide+fade animations (50ms offset between each tile)
    for (int i = 0; i < _tileCount; i++) {
      final start = (i * 0.08).clamp(0.0, 0.9);
      final end = (start + 0.4).clamp(0.0, 1.0);
      _tileAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    }

    // Start animation after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _animatedTile(int index, Widget child) {
    final anim = index < _tileAnimations.length
        ? _tileAnimations[index]
        : const AlwaysStoppedAnimation(1.0);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) {
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - anim.value)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: c.surface0,
      appBar: AppBar(
        backgroundColor: c.surface0,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: BGGoldShimmer(
          child: Text(
            'Ajustes',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: c.goldMid.withValues(alpha: 0.7)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: c.goldMid.withValues(alpha: 0.12),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Hero profile card ────────────────────────────────────────────
          _animatedTile(
            0,
            _BGProfileHeroCard(
              profile: profile,
              username: authState.username,
              onTap: () => context.push('/settings/profile'),
            ),
          ),

          const SizedBox(height: 8),

          // ── Gold membership teaser ───────────────────────────────────────
          _animatedTile(
            1,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _BGGoldMembershipCard(
                onTap: () {},
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Account section ──────────────────────────────────────────────
          _animatedTile(
            2,
            _BGCollapsibleSection(
              label: 'CUENTA',
              expanded: _accountExpanded,
              onToggle: () =>
                  setState(() => _accountExpanded = !_accountExpanded),
              children: [
                _BGSettingTile(
                  icon: Icons.tune_rounded,
                  label: 'Preferencias',
                  onTap: () => context.push('/settings/preferences'),
                ),
                _BGSettingTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'Mis citas',
                  onTap: () => context.push('/my-bookings'),
                ),
                _BGSettingTile(
                  icon: Icons.credit_card_rounded,
                  label: 'Metodos de pago',
                  onTap: () => context.push('/settings/payment-methods'),
                ),
                _BGSettingTile(
                  icon: Icons.palette_outlined,
                  label: 'Apariencia',
                  onTap: () => context.push('/settings/appearance'),
                ),
                _BGSettingTile(
                  icon: Icons.shield_outlined,
                  label: 'Seguridad y cuenta',
                  onTap: () => context.push('/settings/security'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Admin section ────────────────────────────────────────────────
          ref.watch(isAdminProvider).when(
            data: (isAdmin) => isAdmin
                ? _animatedTile(
                    3,
                    _BGCollapsibleSection(
                      label: 'ADMINISTRACION',
                      expanded: true,
                      onToggle: () {},
                      accentColor: c.goldLight,
                      children: [
                        _BGSettingTile(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Panel de administracion',
                          onTap: () => context.push('/admin'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),

          // ── Professionals section ────────────────────────────────────────
          _animatedTile(
            4,
            _BGCollapsibleSection(
              label: 'PARA PROFESIONALES',
              expanded: _proExpanded,
              onToggle: () => setState(() => _proExpanded = !_proExpanded),
              children: [
                _BGSettingTile(
                  icon: Icons.store_rounded,
                  label: 'Registra tu salon',
                  onTap: () => context.push('/registro'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Logout ───────────────────────────────────────────────────────
          _animatedTile(
            5,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _BGLogoutButton(
                onTap: () => _confirmLogout(context, ref),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final c = BGColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.goldMid.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                  ),
                  child: Icon(Icons.logout_rounded,
                      size: 32, color: Colors.red.shade400),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cerrar sesion?',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
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
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                                color: c.goldMid.withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.lato(
                              color: c.goldMid,
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
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cerrar sesion',
                            style: GoogleFonts.lato(
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
        );
      },
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/auth');
    }
  }
}

// ─── Hero profile card with gold gradient border ──────────────────────────────

class _BGProfileHeroCard extends StatelessWidget {
  final dynamic profile;
  final String? username;
  final VoidCallback onTap;

  const _BGProfileHeroCard({
    required this.profile,
    required this.username,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        padding: const EdgeInsets.all(2), // border thickness
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: c.goldGradient,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // Large avatar with gold ring
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: c.goldGradient,
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: c.surface3,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl as String)
                      : null,
                  child: profile.avatarUrl == null
                      ? Icon(
                          Icons.person_outline,
                          color: c.goldMid.withValues(alpha: 0.6),
                          size: 32,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BGGoldShimmer(
                      child: Text(
                        profile.fullName ?? username ?? 'Usuario',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ver y editar perfil',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: c.goldMid.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: c.goldMid.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Gold membership teaser card ─────────────────────────────────────────────

class _BGGoldMembershipCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BGGoldMembershipCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [const Color(0xFF1A1500), const Color(0xFF2A2000), c.goldDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: c.goldMid.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Icon(Icons.workspace_premium_rounded,
                  color: c.goldLight, size: 28),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BeautyCita Gold',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.goldLight,
                    ),
                  ),
                  Text(
                    'Beneficios exclusivos. Pronto.',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: c.goldMid.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.goldMid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: c.goldMid.withValues(alpha: 0.35), width: 0.5),
                ),
                child: Text(
                  'PRONTO',
                  style: GoogleFonts.lato(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.goldLight,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Collapsible section with gold header ────────────────────────────────────

class _BGCollapsibleSection extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Color? accentColor;

  const _BGCollapsibleSection({
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: (accentColor ?? c.goldMid).withValues(alpha: 0.55),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.goldMid.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gold divider
          Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (accentColor ?? c.goldMid).withValues(alpha: 0.3),
                  (accentColor ?? c.goldMid).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          // Animated tile list
          AnimatedCrossFade(
            firstChild: Column(children: children),
            secondChild: const SizedBox.shrink(),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ─── Setting tile ─────────────────────────────────────────────────────────────

class _BGSettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BGSettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = BGColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: c.goldMid.withValues(alpha: 0.05),
        highlightColor: c.goldMid.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: c.goldMid.withValues(alpha: 0.08),
                ),
                child: Icon(icon, size: 20, color: c.goldMid.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text.withValues(alpha: 0.88),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: c.goldMid.withValues(alpha: 0.25),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logout button ────────────────────────────────────────────────────────────

class _BGLogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BGLogoutButton({required this.onTap});

  @override
  State<_BGLogoutButton> createState() => _BGLogoutButtonState();
}

class _BGLogoutButtonState extends State<_BGLogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.45)),
            color: Colors.red.shade900.withValues(alpha: 0.08),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cerrar sesion',
                style: GoogleFonts.lato(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
