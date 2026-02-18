import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/admin_provider.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final goldGrad = ext.goldGradientDirectional();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Profile Card with gold gradient border ──
          GestureDetector(
            onTap: () => context.push('/settings/profile'),
            child: Container(
              decoration: BoxDecoration(
                gradient: goldGrad,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
              child: Container(
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                decoration: BoxDecoration(
                  gradient: ext.primaryGradient,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD - 3),
                ),
                child: Row(
                  children: [
                    // Avatar with gold stroke
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: goldGrad,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? const Icon(Icons.person_outline, color: Colors.white, size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Username with gold shimmer
                          _GoldShimmerText(
                            text: profile.fullName ?? authState.username ?? 'Usuario',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // "Editar perfil" with static gold
                          ShaderMask(
                            shaderCallback: (bounds) => goldGrad.createShader(bounds),
                            child: Text(
                              'Editar perfil',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pencil icon — gold
                    ShaderMask(
                      shaderCallback: (bounds) => goldGrad.createShader(bounds),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Chevron — gold
                    ShaderMask(
                      shaderCallback: (bounds) => goldGrad.createShader(bounds),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Navigation tiles ──
          SettingsTile(
            icon: Icons.tune_rounded,
            label: 'Preferencias',
            onTap: () => context.push('/settings/preferences'),
          ),
          SettingsTile(
            icon: Icons.calendar_today_rounded,
            label: 'Mis citas',
            onTap: () => context.push('/my-bookings'),
          ),
          SettingsTile(
            icon: Icons.credit_card_rounded,
            label: 'Metodos de pago',
            onTap: () => context.push('/settings/payment-methods'),
          ),
          SettingsTile(
            icon: Icons.palette_outlined,
            label: 'Apariencia',
            onTap: () => context.push('/settings/appearance'),
          ),
          SettingsTile(
            icon: Icons.shield_outlined,
            label: 'Seguridad y cuenta',
            onTap: () => context.push('/settings/security'),
          ),

          // ── Admin panel (only for admin/superadmin) ──
          ref.watch(isAdminProvider).when(
            data: (isAdmin) => isAdmin
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppConstants.paddingLG),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'ADMINISTRACION',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Panel de administracion',
                        onTap: () => context.push('/admin'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Salon section ──
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PARA PROFESIONALES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SettingsTile(
            icon: Icons.store_rounded,
            label: 'Registra tu salon',
            onTap: () => context.push('/registro'),
          ),

          const SizedBox(height: AppConstants.paddingXL),

          // ── Logout ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(Icons.logout_rounded, size: AppConstants.iconSizeXL, color: Colors.red.shade400),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Cerrar sesion?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          minimumSize: const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text(
                          'Cerrar sesion',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
      if (context.mounted) {
        context.go('/auth');
      }
    }
  }
}

/// Gold shimmer text — animates a highlight sweep across the gold gradient.
class _GoldShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _GoldShimmerText({required this.text, this.style});

  @override
  State<_GoldShimmerText> createState() => _GoldShimmerTextState();
}

class _GoldShimmerTextState extends State<_GoldShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = _controller.value * 3.0 - 1.0;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD4AF37),
                Color(0xFFFFF8DC),
                Color(0xFFFFD700),
                Color(0xFFFFFFE0),
                Color(0xFFFFF8DC),
                Color(0xFFD4AF37),
              ],
              stops: [
                (shimmerOffset - 0.3).clamp(0.0, 1.0),
                (shimmerOffset - 0.1).clamp(0.0, 1.0),
                shimmerOffset.clamp(0.0, 1.0),
                (shimmerOffset + 0.1).clamp(0.0, 1.0),
                (shimmerOffset + 0.3).clamp(0.0, 1.0),
                (shimmerOffset + 0.5).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: (widget.style ?? const TextStyle()).copyWith(
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
