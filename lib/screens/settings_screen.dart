import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
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
          // User profile card
          Container(
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
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: BeautyCitaTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.username ?? 'Usuario',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cuenta anonima',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // Section: General
          _SectionHeader(label: 'General'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _SettingsTile(
            icon: Icons.calendar_today_rounded,
            label: 'Mis citas',
            onTap: () => context.push('/my-bookings'),
          ),
          _SettingsTile(
            icon: Icons.storefront_rounded,
            label: 'Invitar un salon',
            onTap: () => context.push('/invite'),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // Section: About
          _SectionHeader(label: 'Acerca de'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Version',
            trailing: Text(
              '0.1.0',
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceXL),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                    ),
                    title: const Text('Cerrar sesion'),
                    content: const Text(
                      'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        child: const Text('Cerrar sesion'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.paddingMD,
                ),
              ),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: BeautyCitaTheme.textLight,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingSM,
            vertical: AppConstants.paddingMD,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppConstants.iconSizeMD,
                color: BeautyCitaTheme.primaryRose,
              ),
              const SizedBox(width: BeautyCitaTheme.spaceMD),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: BeautyCitaTheme.textLight.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
