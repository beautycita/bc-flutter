// =============================================================================
// Profile Sections — extracted from the consolidated profile screen
// =============================================================================
// These widgets used to live in settings_screen.dart. After settings was
// dropped (2026-04-26) they moved here so profile_screen stays under ~1500
// lines. Each is a self-contained ConsumerWidget that reads its own providers.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:beautycita/config/app_transitions.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/providers/admin_provider.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/business_provider.dart';
import 'package:beautycita/providers/feature_toggle_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/security_provider.dart';
import 'package:beautycita/screens/admin/admin_shell_screen.dart' show adminTabProvider;
import 'package:beautycita/screens/business/business_shell_screen.dart' show businessTabProvider;
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

// =============================================================================
// Admin tile (only renders for admin/superadmin)
// =============================================================================

class ProfileAdminTile extends ConsumerWidget {
  const ProfileAdminTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isAdminProvider).when(
          data: (isAdmin) => isAdmin
              ? _LabeledSection(
                  label: 'ADMINISTRACION',
                  child: SettingsTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Panel de administracion',
                    onTap: () {
                      ref.read(adminTabProvider.notifier).state = 0;
                      context.push(AppRoutes.admin);
                    },
                  ),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

// =============================================================================
// RP tile (only renders for rp role)
// =============================================================================

class ProfileRpTile extends ConsumerWidget {
  const ProfileRpTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isRpProvider).when(
          data: (isRp) => isRp
              ? _LabeledSection(
                  label: 'RELACIONES PUBLICAS',
                  child: SettingsTile(
                    icon: Icons.business_center,
                    label: 'Panel RP',
                    onTap: () => context.push(AppRoutes.rp),
                  ),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

// =============================================================================
// Para profesionales — full salon-onboarding state machine
// =============================================================================
// State table:
//   isOwner=true                      → Portal de negocio tile
//   appStatus='pending'               → "Solicitud en revision" tile
//   appStatus='rejected'              → "Solicitud rechazada" + retry tile
//   role in (admin, superadmin, stylist) → hidden
//   appOpens >= 10                    → hidden (banner-fatigue gate, see below)
//   else                              → "Registra tu salon" tile
//
// The appOpens<10 gate: salon-registration banner shows ONLY for the first 10
// cold launches of a customer. After that we stop bothering them. This is the
// confirmed UX (Kriket 2026-04-26 during settings/profile consolidation).
// =============================================================================

class ProfileProfessionalsSection extends ConsumerWidget {
  const ProfileProfessionalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStatus = ref.watch(applicationStatusProvider).valueOrNull;
    final isOwner = ref.watch(isBusinessOwnerProvider).valueOrNull ?? false;

    if (isOwner) {
      return _LabeledSection(
        label: 'PARA PROFESIONALES',
        child: SettingsTile(
          icon: Icons.storefront_rounded,
          label: 'Portal de negocio',
          onTap: () {
            ref.read(businessTabProvider.notifier).state = 0;
            context.push(AppRoutes.business);
          },
        ),
      );
    }

    if (appStatus == 'pending') {
      return _LabeledSection(
        label: 'PARA PROFESIONALES',
        child: SettingsTile(
          icon: Icons.hourglass_top_rounded,
          label: 'Solicitud en revision',
          trailing: _StatusPill(
            text: 'Pendiente',
            color: Colors.amber.shade800,
            background: Colors.amber.shade100,
          ),
          onTap: () {},
        ),
      );
    }

    if (appStatus == 'rejected') {
      final cs = Theme.of(context).colorScheme;
      return _LabeledSection(
        label: 'PARA PROFESIONALES',
        children: [
          SettingsTile(
            icon: Icons.error_outline_rounded,
            label: 'Solicitud rechazada',
            trailing: _StatusPill(
              text: 'Rechazada',
              color: cs.error,
              background: cs.error.withValues(alpha: 0.08),
            ),
            onTap: () {},
          ),
          SettingsTile(
            icon: Icons.refresh_rounded,
            label: 'Intentar de nuevo',
            onTap: () => _attemptRegister(context, ref),
          ),
        ],
      );
    }

    final toggles = ref.watch(featureTogglesProvider);
    if (!toggles.isEnabled('enable_salon_registration')) {
      return const SizedBox.shrink();
    }

    final role = ref.watch(userRoleProvider).valueOrNull;
    if (role == 'admin' || role == 'superadmin' || role == 'stylist') {
      return const SizedBox.shrink();
    }

    final appOpens = ref.watch(appOpenCountProvider).valueOrNull ?? 0;
    if (appOpens >= 10) return const SizedBox.shrink();

    return _LabeledSection(
      label: 'PARA PROFESIONALES',
      child: SettingsTile(
        icon: Icons.store_rounded,
        label: 'Registra tu salon',
        onTap: () => _attemptRegister(context, ref),
      ),
    );
  }

  void _attemptRegister(BuildContext context, WidgetRef ref) {
    final phoneVerified = ref.read(profileProvider).hasVerifiedPhone;
    final emailVerified = ref.read(securityProvider).isEmailConfirmed;
    if (phoneVerified && emailVerified) {
      context.push('/registro');
    } else {
      ToastService.showWarning(
        'Para registrar tu salon necesitas verificar tu numero de telefono '
        'y confirmar tu email. Hazlo desde tu Perfil para completar la verificacion.',
      );
    }
  }
}

// =============================================================================
// Legal tile
// =============================================================================

class ProfileLegalSection extends StatelessWidget {
  const ProfileLegalSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _LabeledSection(
      label: 'LEGAL',
      child: SettingsTile(
        icon: Icons.gavel_rounded,
        label: 'Terminos y politicas',
        onTap: () => context.push(AppRoutes.legal),
      ),
    );
  }
}

// =============================================================================
// Cerrar sesion button + confirm sheet
// =============================================================================

class ProfileLogoutButton extends ConsumerWidget {
  const ProfileLogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context, ref),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesion'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showBurstBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(Icons.logout_rounded,
                    size: AppConstants.iconSizeXL, color: cs.error),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Cerrar sesion?',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Se cerrara tu sesion y tendras que autenticarte de nuevo.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
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
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusLG),
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
                          backgroundColor: cs.error,
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusLG),
                          ),
                        ),
                        child: Text(
                          'Cerrar sesion',
                          style: TextStyle(
                              color: cs.onPrimary, fontWeight: FontWeight.w700),
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

    if (confirmed != true) return;
    if (!context.mounted) return;
    await showShredderTransition(context);
    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) context.go('/auth');
  }
}

// =============================================================================
// Small private helpers
// =============================================================================

class _LabeledSection extends StatelessWidget {
  final String label;
  final Widget? child;
  final List<Widget>? children;

  const _LabeledSection({required this.label, this.child, this.children})
      : assert(child != null || children != null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingLG),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: cs.primary,
                ),
          ),
        ),
        if (child != null) child!,
        if (children != null) ...children!,
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const _StatusPill(
      {required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
