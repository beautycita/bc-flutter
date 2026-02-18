import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import 'cb_widgets.dart';

// ─── CBSettingsScreen ──────────────────────────────────────────────────────────
class CBSettingsScreen extends ConsumerWidget {
  const CBSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CBColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: Icon(
            Icons.chevron_left,
            color: c.pink.withValues(alpha: 0.55),
            size: 28,
          ),
        ),
        title: Text(
          'Ajustes',
          style: GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: c.text,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // ── Profile card ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/settings/profile'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: c.pink.withValues(alpha: 0.18),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.pink.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar with pink gradient ring
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          c.pink.withValues(alpha: 0.60),
                          c.lavender.withValues(alpha: 0.60),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.card,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: c.bg,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Icon(
                                Icons.person_outline,
                                color: c.pink.withValues(alpha: 0.40),
                                size: 26,
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
                        Text(
                          profile.fullName ?? authState.username ?? 'Usuario',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Editar perfil',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            color: c.pink.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.chevron_right,
                    color: c.pink.withValues(alpha: 0.30),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Cuenta section ────────────────────────────────────────────
          _CBSectionHeader(label: 'Cuenta'),
          const SizedBox(height: 12),

          _CBSettingTile(
            label: 'Preferencias',
            onTap: () => context.push('/settings/preferences'),
          ),
          _CBTileDivider(),
          _CBSettingTile(
            label: 'Mis citas',
            onTap: () => context.push('/my-bookings'),
          ),
          _CBTileDivider(),
          _CBSettingTile(
            label: 'Metodos de pago',
            onTap: () => context.push('/settings/payment-methods'),
          ),

          const SizedBox(height: 28),

          // ── Preferencias section ──────────────────────────────────────
          _CBSectionHeader(label: 'Preferencias'),
          const SizedBox(height: 12),

          _CBSettingTile(
            label: 'Apariencia',
            onTap: () => context.push('/settings/appearance'),
          ),

          const SizedBox(height: 28),

          // ── Seguridad section ─────────────────────────────────────────
          _CBSectionHeader(label: 'Seguridad'),
          const SizedBox(height: 12),

          _CBSettingTile(
            label: 'Seguridad y cuenta',
            onTap: () => context.push('/settings/security'),
          ),

          // ── Admin section (conditional) ───────────────────────────────
          ref.watch(isAdminProvider).when(
            data: (isAdmin) => isAdmin
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      _CBSectionHeader(label: 'Administracion'),
                      const SizedBox(height: 12),
                      _CBSettingTile(
                        label: 'Panel de administracion',
                        onTap: () => context.push('/admin'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 28),

          // ── Para profesionales ────────────────────────────────────────
          _CBSectionHeader(label: 'Para Profesionales'),
          const SizedBox(height: 12),

          _CBSettingTile(
            label: 'Registra tu salon',
            onTap: () => context.push('/registro'),
          ),

          const SizedBox(height: 36),

          // ── Thin pink separator ───────────────────────────────────────
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.pink.withValues(alpha: 0.0),
                  c.pink.withValues(alpha: 0.18),
                  c.pink.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Logout — plain tappable text, no border ───────────────────
          GestureDetector(
            onTap: () => _confirmLogout(context, ref),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Text(
                'Cerrar sesion',
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final c = CBColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final cs = CBColors.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: cs.pink.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Cerrar sesion?',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: cs.text,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Tendras que autenticarte de nuevo la proxima vez.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 14,
                    color: cs.text.withValues(alpha: 0.45),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: cs.bg,
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: cs.pink.withValues(alpha: 0.15),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.nunitoSans(
                              color: cs.text.withValues(alpha: 0.55),
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
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(23),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cerrar sesion',
                            style: GoogleFonts.nunitoSans(
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

// ─── Section header — Cormorant Garamond italic ────────────────────────────────
class _CBSectionHeader extends StatelessWidget {
  final String label;
  const _CBSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: c.pink.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.pink.withValues(alpha: 0.20),
                  c.pink.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Settings tile — clean text + subtle pink chevron ─────────────────────────
class _CBSettingTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CBSettingTile({required this.label, required this.onTap});

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
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunitoSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.text.withValues(alpha: 0.88),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: c.pink.withValues(alpha: 0.30),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile divider — thin pink gradient line ────────────────────────────────────
class _CBTileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = CBColors.of(context);
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.pink.withValues(alpha: 0.0),
            c.pink.withValues(alpha: 0.12),
            c.pink.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
