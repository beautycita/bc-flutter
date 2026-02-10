import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: BeautyCitaTheme.spaceMD,
        ),
        children: [
          // ── Profile Card ──
          GestureDetector(
            onTap: () => context.push('/settings/profile'),
            child: Container(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              decoration: BoxDecoration(
                gradient: BeautyCitaTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? const Icon(Icons.person_outline, color: Colors.white, size: 28)
                        : null,
                  ),
                  const SizedBox(width: BeautyCitaTheme.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName ?? authState.username ?? 'Usuario',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Editar perfil',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

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
            icon: Icons.shield_outlined,
            label: 'Seguridad y cuenta',
            onTap: () => context.push('/settings/security'),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceXL),

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

          const SizedBox(height: BeautyCitaTheme.spaceLG),
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
                const SizedBox(height: BeautyCitaTheme.spaceMD),
                Icon(Icons.logout_rounded, size: AppConstants.iconSizeXL, color: Colors.red.shade400),
                const SizedBox(height: BeautyCitaTheme.spaceSM),
                Text(
                  'Cerrar sesion?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceXS),
                Text(
                  'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceLG),
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
                    const SizedBox(width: BeautyCitaTheme.spaceSM),
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
