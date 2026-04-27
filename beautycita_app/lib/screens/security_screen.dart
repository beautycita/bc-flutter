import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/providers/security_provider.dart';
import 'package:beautycita/services/biometric_preferences.dart';
import 'package:beautycita/services/biometric_service.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/services/user_session.dart';
import 'package:beautycita/widgets/phone_verify_gate_sheet.dart';
import 'package:beautycita/services/updater_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';
import 'package:beautycita/widgets/profile_sections.dart';
import 'package:beautycita/config/routes.dart';
import 'package:url_launcher/url_launcher.dart';

/// Section selector for SecurityScreen. When null, the screen renders the
/// 5-tile nav menu. When set, only that section's card is rendered with
/// its own AppBar — used so the menu links each go to a focused page
/// (linked accounts, biometric, about).
enum SecuritySection { linkedAccounts, biometric, about }

class SecurityScreen extends ConsumerStatefulWidget {
  final SecuritySection? section;
  const SecurityScreen({super.key, this.section});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen>
    with SingleTickerProviderStateMixin {
  bool _checkingUpdate = false;

  late final AnimationController _entryController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    const count = 4; // linked accounts, biometric, devices, about
    _fadeAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _slideAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });
    _entryController.forward();
    Future.microtask(() {
      ref.read(securityProvider.notifier).checkIdentities();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sec = ref.watch(securityProvider);
    final textTheme = Theme.of(context).textTheme;

    // Listen for success/error messages
    ref.listen<SecurityState>(securityProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ToastService.showSuccess(next.successMessage!);
        ref.read(securityProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ToastService.showError(next.error!);
        ref.read(securityProvider.notifier).clearMessages();
      }
    });

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    // Menu mode — render the 5-tile nav, no inline sections.
    if (widget.section == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Seguridad')),
        body: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingHorizontal,
            vertical: AppConstants.paddingMD,
          ),
          children: [
            ProfileQuickLinkTile(
              icon: Icons.account_tree_outlined,
              label: 'Cuentas vinculadas',
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push('/cuenta/security/linked-accounts'),
            ),
            ProfileQuickLinkTile(
              icon: Icons.fingerprint_rounded,
              label: 'Biometrico',
              color: const Color(0xFF0EA5E9),
              onTap: () => context.push('/cuenta/security/biometric'),
            ),
            ProfileQuickLinkTile(
              icon: Icons.devices_outlined,
              label: 'Dispositivos enlazados',
              color: const Color(0xFFEC4899),
              onTap: () => context.push('/devices'),
            ),
            ProfileQuickLinkTile(
              icon: Icons.credit_card_outlined,
              label: 'Metodos de pago',
              color: const Color(0xFFEF4444),
              onTap: () => context.push(AppRoutes.paymentMethods),
            ),
            ProfileQuickLinkTile(
              icon: Icons.info_outline_rounded,
              label: 'Acerca de la app',
              color: const Color(0xFF6B7280),
              onTap: () => context.push('/cuenta/security/about'),
            ),
          ],
        ),
      );
    }

    final showLinked = widget.section == SecuritySection.linkedAccounts;
    final showBiometric = widget.section == SecuritySection.biometric;
    final showAbout = widget.section == SecuritySection.about;
    final title = showLinked
        ? 'Cuentas vinculadas'
        : showBiometric
            ? 'Biometrico'
            : 'Acerca de la app';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Cuentas vinculadas ──
          if (showLinked) _animated(0, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Cuentas vinculadas'),

              _buildCard(cs, ext, children: [
                // Google
                SettingsTile(
              icon: Icons.g_mobiledata_outlined,
              iconColor: sec.isGoogleLinked ? ext.successColor : null,
              label: sec.isGoogleLinked ? 'Google vinculado' : 'Vincular Google',
              trailing: sec.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : sec.isGoogleLinked
                      ? Icon(Icons.check_circle_outlined, color: ext.successColor, size: 20)
                      : null,
              onTap: sec.isGoogleLinked ? null : () => ref.read(securityProvider.notifier).linkGoogle(),
            ),

            Divider(height: 1, color: ext.cardBorderColor),

            // Email
            SettingsTile(
              icon: Icons.email_outlined,
              iconColor: sec.isEmailConfirmed ? ext.successColor : sec.isEmailAdded ? ext.warningColor : null,
              label: sec.isEmailAdded ? (sec.email ?? 'Email agregado') : 'Agregar email',
              trailing: sec.isEmailConfirmed
                  ? Icon(Icons.check_circle_outlined, color: ext.successColor, size: 20)
                  : sec.isEmailAdded
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ext.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                          ),
                          child: Text(
                            'Verificar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ext.warningColor,
                            ),
                          ),
                        )
                      : null,
              onTap: sec.isEmailAdded ? null : () => _showEmailSheet(context),
            ),

            Divider(height: 1, color: ext.cardBorderColor),

            // Phone
            Consumer(builder: (ctx, ref, _) {
              final profile = ref.watch(profileProvider);
              final hasPhone = profile.phone != null;
              final verified = profile.hasVerifiedPhone;
              return SettingsTile(
                icon: Icons.phone_outlined,
                iconColor: verified ? ext.successColor : hasPhone ? ext.warningColor : null,
                label: hasPhone ? (profile.phone ?? 'Telefono') : 'Agregar telefono',
                trailing: verified
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Verificado', style: TextStyle(fontSize: 11, color: ext.successColor, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_outlined, color: ext.successColor, size: 20),
                        ],
                      )
                    : hasPhone
                        ? GestureDetector(
                            onTap: () => _showOtpSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ext.warningColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                              ),
                              child: Text('Verificar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ext.warningColor)),
                            ),
                          )
                        : Text('Requerido', style: TextStyle(fontSize: 11, color: cs.error.withValues(alpha: 0.7))),
                onTap: hasPhone ? null : () => _showPhoneSheet(context),
              );
            }),

            Divider(height: 1, color: ext.cardBorderColor),

            // Password
            if (sec.hasPassword)
              SettingsTile(
                icon: Icons.lock_outlined,
                iconColor: ext.successColor,
                label: 'Protegida',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'cambiar',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_outlined, color: ext.successColor, size: 20),
                  ],
                ),
                onTap: () => _showPasswordSheet(context),
              )
            else
              SettingsTile(
                icon: Icons.lock_open_outlined,
                iconColor: _canAddPassword(sec) ? ext.warningColor : cs.error.withValues(alpha: 0.7),
                label: 'Agregar contrasena',
                trailing: !_canAddPassword(sec)
                    ? Text(
                        sec.isEmailAdded ? 'Confirma email' : 'Requiere email',
                        style: textTheme.bodySmall?.copyWith(color: cs.error.withValues(alpha: 0.7), fontSize: 11),
                      )
                    : Icon(Icons.chevron_right_outlined, size: 20,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                onTap: _canAddPassword(sec)
                    ? () => _showPasswordSheet(context)
                    : () {
                        ToastService.showWarning(
                          sec.isEmailAdded
                              ? 'Confirma tu email primero (revisa tu bandeja)'
                              : 'Agrega tu email primero',
                        );
                      },
              ),
              ]),
            ],
          )),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Biometrico ──
          if (showBiometric) _animated(1, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Biometrico'),
              _buildCard(cs, ext, children: [
                _BiometricToggleTile(),
                Divider(height: 1, color: ext.cardBorderColor),
                _BiometricRegisterTile(),
                Divider(height: 1, color: ext.cardBorderColor),
                _BiometricForgetTile(),
              ]),
            ],
          )),

          if (showBiometric) const SizedBox(height: AppConstants.paddingLG),

          // Dispositivos section moved out — the Seguridad menu links
          // directly to /devices (the existing devices screen).

          // ── Acerca de ──
          if (showAbout) _animated(3, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Acerca de'),

              _buildCard(cs, ext, children: [
            // Update button (only if newer build available)
            if (UpdaterService.instance.apkUpdateAvailable) ...[
              SettingsTile(
                icon: Icons.system_update_outlined,
                iconColor: ext.infoColor,
                label: 'Actualizar a ${UpdaterService.instance.apkUpdateVersion}',
                trailing: Icon(Icons.download_outlined, color: ext.infoColor, size: 20),
                onTap: () => _launchUpdate(),
              ),
              Divider(height: 1, color: ext.cardBorderColor),
            ],

            SettingsTile(
              icon: Icons.info_outlined,
              label: 'Version',
              trailing: Text(
                '${AppConstants.version} (${AppConstants.buildNumber})',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Divider(height: 1, color: ext.cardBorderColor),

            SettingsTile(
              icon: Icons.refresh_outlined,
              iconColor: ext.infoColor,
              label: 'Buscar actualizaciones',
              trailing: _checkingUpdate
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.chevron_right_outlined, size: 20,
                      color: cs.onSurface.withValues(alpha: 0.3)),
              onTap: _checkingUpdate ? null : () => _checkForUpdates(),
            ),
              ]),
            ],
          )),

          const SizedBox(height: AppConstants.paddingXXL),
        ],
      ),
    );
  }

  Widget _buildCard(ColorScheme cs, BCThemeExtension ext, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  void _launchUpdate() {
    final url = UpdaterService.instance.apkUpdateUrl;
    if (url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    await UpdaterService.instance.checkForApkUpdate(force: true);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (UpdaterService.instance.apkUpdateAvailable) {
      ToastService.showSuccess(
        'Actualización disponible: v${UpdaterService.instance.apkUpdateVersion}',
      );
    } else {
      ToastService.showSuccess('Tu app está al día');
    }
  }

  /// Google users can always add a password (email verified by Google).
  /// Email-only users need confirmed email first.
  void _showPhoneSheet(BuildContext context) {
    final controller = TextEditingController();
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agregar telefono', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Ingresa tu numero de 10 digitos', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '+52 ',
                hintText: '3221234567',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final phone = controller.text.trim();
                  if (phone.length < 10) {
                    ToastService.showWarning('Ingresa un numero de 10 digitos');
                    return;
                  }
                  final fullPhone = '+52$phone';
                  ref.read(profileProvider.notifier).updatePhone(fullPhone);
                  Navigator.pop(context);
                  ToastService.showSuccess('Telefono guardado. Ahora verificalo.');
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtpSheet(BuildContext context) {
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PhoneVerifyGateSheet(),
    );
  }

  bool _canAddPassword(SecurityState sec) {
    if (sec.isGoogleLinked) return true;
    return sec.isEmailConfirmed;
  }

  void _showEmailSheet(BuildContext context) {
    final controller = TextEditingController();
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSheetHeader(context, 'Agregar email'),
              Text(
                'Necesario para recibos de reservas y para recuperar tu cuenta.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'tu@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final email = controller.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ToastService.showError('Ingresa un email valido');
                      return;
                    }
                    Navigator.pop(ctx);
                    ref.read(securityProvider.notifier).addEmail(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    ),
                  ),
                  child: const Text('Agregar email'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPasswordSheet(BuildContext context) {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 16, 24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSheetHeader(context, 'Configurar contrasena'),
                  Text(
                    'Podras iniciar sesion con tu email y contrasena en cualquier dispositivo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Contrasena (min. 8 caracteres)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setSheetState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      hintText: 'Confirmar contrasena',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final pass = passController.text;
                        final confirm = confirmController.text;
                        if (pass.length < 8) {
                          ToastService.showError('La contrasena debe tener al menos 8 caracteres');
                          return;
                        }
                        if (pass != confirm) {
                          ToastService.showError('Las contrasenas no coinciden');
                          return;
                        }
                        Navigator.pop(ctx);
                        ref.read(securityProvider.notifier).addPassword(pass);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                        ),
                      ),
                      child: const Text('Guardar contrasena'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Biometric tiles
// =============================================================================

class _BiometricToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final enabledAsync = ref.watch(biometricEnabledProvider);
    final enabled = enabledAsync.valueOrNull ?? true;

    return SettingsTile(
      icon: Icons.fingerprint,
      iconColor: enabled ? ext.successColor : null,
      label: 'Inicio de sesion biometrico',
      trailing: Switch(
        value: enabled,
        onChanged: (v) async {
          await ref.setBiometricEnabled(v);
          if (context.mounted) {
            ToastService.showSuccess(
              v ? 'Biometrico activado en este dispositivo'
                : 'Biometrico desactivado en este dispositivo',
            );
          }
        },
      ),
    );
  }
}

class _BiometricRegisterTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BiometricRegisterTile> createState() => _BiometricRegisterTileState();
}

class _BiometricRegisterTileState extends ConsumerState<_BiometricRegisterTile> {
  bool _running = false;

  Future<void> _registerThisDevice() async {
    setState(() => _running = true);
    try {
      final bio = BiometricService();
      final available = await bio.isBiometricAvailable();
      if (!available) {
        if (mounted) ToastService.showError('Este dispositivo no soporta biometrico');
        return;
      }
      final ok = await bio.authenticate();
      if (!ok) {
        if (mounted) ToastService.showError('Autenticacion biometrica fallida');
        return;
      }
      // Persist current Supabase user_id into secure storage so future
      // biometric logins on this device work without password.
      final session = UserSession();
      final supabaseId = SupabaseClientService.currentUserId;
      if (supabaseId == null) {
        if (mounted) ToastService.showError('No hay sesion activa');
        return;
      }
      await session.saveSupabaseUserId(supabaseId);
      if (mounted) {
        ToastService.showSuccess('Dispositivo registrado para biometrico');
      }
    } catch (e) {
      if (mounted) ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsTile(
      icon: Icons.add_circle_outline,
      label: 'Registrar este dispositivo',
      trailing: _running
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.chevron_right_outlined, size: 20, color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: _running ? null : _registerThisDevice,
    );
  }
}

class _BiometricForgetTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BiometricForgetTile> createState() => _BiometricForgetTileState();
}

class _BiometricForgetTileState extends ConsumerState<_BiometricForgetTile> {
  bool _running = false;

  Future<void> _forgetThisDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Olvidar este dispositivo'),
        content: const Text(
          'Se borrara el registro biometrico de este dispositivo. '
          'En el proximo inicio de sesion deberas usar email y contrasena, '
          'o registrar de nuevo el biometrico aqui.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Olvidar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _running = true);
    try {
      // Wipe local biometric state but DO NOT sign out the active Supabase
      // session — we just want next-launch biometric to require re-register.
      await UserSession().clearBiometricRegistration();
      if (mounted) ToastService.showSuccess('Biometrico borrado de este dispositivo');
    } catch (e) {
      if (mounted) ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsTile(
      icon: Icons.no_encryption_outlined,
      iconColor: cs.error,
      label: 'Olvidar biometrico de este dispositivo',
      trailing: _running
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.chevron_right_outlined, size: 20, color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: _running ? null : _forgetThisDevice,
    );
  }
}
