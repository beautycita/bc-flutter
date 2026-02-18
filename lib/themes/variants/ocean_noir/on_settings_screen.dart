import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/admin_provider.dart';
import 'on_widgets.dart';

class ONSettingsScreen extends ConsumerWidget {
  const ONSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ONColors.of(context);
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: c.surface0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Terminal-style app bar ────────────────────────────────────
            _SettingsAppBar(),

            // Thin separator
            Container(height: 0.5, color: c.cyan.withValues(alpha: 0.25)),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                children: [
                  // Section: PERFIL_USUARIO
                  _TypedSectionHeader(
                    label: 'PERFIL_USUARIO',
                    startDelay: Duration.zero,
                  ),
                  const SizedBox(height: 10),

                  // HUD profile card
                  GestureDetector(
                    onTap: () => context.push('/settings/profile'),
                    child: ONHudFrame(
                      bracketSize: 18,
                      bracketThickness: 1.5,
                      color: c.cyan.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Angular avatar
                          ClipPath(
                            clipper: const ONAngularClipper(clipSize: 8),
                            child: Container(
                              width: 56,
                              height: 56,
                              color: c.surface2,
                              child: profile.avatarUrl != null
                                  ? Image.network(
                                      profile.avatarUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.person_outline,
                                      color: c.cyan.withValues(alpha: 0.6),
                                      size: 30,
                                    ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name in data readout style
                                Text(
                                  'NOMBRE: ${(profile.fullName ?? authState.username ?? 'USUARIO').toUpperCase()}',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12,
                                    color: c.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ESTADO: ACTIVO',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 10,
                                    color: c.green.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '> editar_perfil',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 10,
                                    color: c.cyan.withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons.chevron_right,
                            color: c.cyan.withValues(alpha: 0.35),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section: CONFIGURACION_SISTEMA
                  _TypedSectionHeader(
                    label: 'CONFIGURACION_SISTEMA',
                    startDelay: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(height: 10),

                  _TerminalTile(
                    prefix: 'PRF',
                    label: 'Preferencias',
                    onTap: () => context.push('/settings/preferences'),
                  ),
                  _TerminalTile(
                    prefix: 'CIT',
                    label: 'Mis citas',
                    onTap: () => context.push('/my-bookings'),
                  ),
                  _TerminalTile(
                    prefix: 'PAG',
                    label: 'Metodos de pago',
                    onTap: () =>
                        context.push('/settings/payment-methods'),
                  ),
                  _TerminalTile(
                    prefix: 'APA',
                    label: 'Apariencia',
                    onTap: () =>
                        context.push('/settings/appearance'),
                  ),
                  _TerminalTile(
                    prefix: 'SEC',
                    label: 'Seguridad y cuenta',
                    onTap: () => context.push('/settings/security'),
                  ),

                  const SizedBox(height: 20),

                  // Admin section
                  ref.watch(isAdminProvider).when(
                    data: (isAdmin) => isAdmin
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 0.5,
                                color: c.cyan.withValues(alpha: 0.15),
                                margin:
                                    const EdgeInsets.only(bottom: 16),
                              ),
                              _TypedSectionHeader(
                                label: 'ACCESO_ADMINISTRADOR',
                                startDelay:
                                    const Duration(milliseconds: 300),
                              ),
                              const SizedBox(height: 10),
                              _TerminalTile(
                                prefix: 'ADM',
                                label: 'Panel de administracion',
                                onTap: () => context.push('/admin'),
                                color: c.cyan,
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Section: PARA_PROFESIONALES
                  Container(
                    height: 0.5,
                    color: c.cyan.withValues(alpha: 0.15),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                  _TypedSectionHeader(
                    label: 'PARA_PROFESIONALES',
                    startDelay: const Duration(milliseconds: 400),
                  ),
                  const SizedBox(height: 10),
                  _TerminalTile(
                    prefix: 'SAL',
                    label: 'Registra tu salon',
                    onTap: () => context.push('/registro'),
                  ),

                  const SizedBox(height: 32),

                  // Logout: >> CERRAR SESION
                  _LogoutButton(
                    onTap: () => _confirmLogout(context, ref),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ONColors.of(ctx);
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface1,
            border: Border.all(
              color: c.red.withValues(alpha: 0.4),
              width: 1,
            ),
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
                  Icon(Icons.logout_rounded, size: 40, color: c.red),
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
                  const SizedBox(height: 6),
                  Text(
                    'Se cerrara tu sesion.\nTendras que autenticarte de nuevo.',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      color: c.text.withValues(alpha: 0.35),
                    ),
                    textAlign: TextAlign.center,
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
      },
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/auth');
    }
  }
}

// ─── Settings app bar ─────────────────────────────────────────────────────────

class _SettingsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return Container(
      color: c.surface0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                border: Border.all(color: c.cyan.withValues(alpha: 0.2)),
              ),
              child: Icon(
                Icons.arrow_back,
                color: c.cyan.withValues(alpha: 0.7),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '> ',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: c.cyan.withValues(alpha: 0.4),
            ),
          ),
          Text(
            'AJUSTES',
            style: GoogleFonts.rajdhani(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
              letterSpacing: 2.5,
            ),
          ),
          const Spacer(),
          // Small status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.green,
              boxShadow: [
                BoxShadow(
                  color: c.green.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header with typing cursor ────────────────────────────────────────

class _TypedSectionHeader extends StatefulWidget {
  final String label;
  final Duration startDelay;
  const _TypedSectionHeader({required this.label, this.startDelay = Duration.zero});

  @override
  State<_TypedSectionHeader> createState() => _TypedSectionHeaderState();
}

class _TypedSectionHeaderState extends State<_TypedSectionHeader> {
  int _visible = 0;
  bool _cursorOn = true;
  Timer? _typingTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 530),
      (_) => mounted ? setState(() => _cursorOn = !_cursorOn) : null,
    );
    Future.delayed(widget.startDelay, _startTyping);
  }

  void _startTyping() {
    if (!mounted) return;
    _typingTimer = Timer.periodic(
      const Duration(milliseconds: 35),
      (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          if (_visible < widget.label.length) {
            _visible++;
          } else {
            t.cancel();
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    final shown = widget.label.substring(0, _visible);
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 12,
            color: c.cyan,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(
            '// $shown',
            style: GoogleFonts.firaCode(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: c.cyan.withValues(alpha: 0.55),
            ),
          ),
          if (_visible < widget.label.length)
            Text(
              _cursorOn ? '|' : ' ',
              style: GoogleFonts.firaCode(
                fontSize: 11,
                color: c.cyan.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Terminal tile ─────────────────────────────────────────────────────────────

class _TerminalTile extends StatelessWidget {
  final String prefix;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _TerminalTile({
    required this.prefix,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    final effectiveColor = color ?? c.cyan;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: effectiveColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Row(
            children: [
              // Prefix badge
              Container(
                width: 34,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: effectiveColor.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  prefix,
                  style: GoogleFonts.firaCode(
                    fontSize: 9,
                    color: effectiveColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '> ',
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: effectiveColor.withValues(alpha: 0.4),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: effectiveColor.withValues(alpha: 0.25),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logout button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ONColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: const ONAngularClipper(clipSize: 14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: c.red.withValues(alpha: 0.08),
            border: Border.all(
              color: c.red.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '>>',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: c.red.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'CERRAR SESION',
                style: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.red,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
