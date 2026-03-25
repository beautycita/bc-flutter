import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/providers/security_provider.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/services/updater_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

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
    const count = 3; // linked accounts, devices, about
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Cuentas vinculadas ──
          _animated(0, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Cuentas vinculadas'),

              _buildCard(cs, ext, children: [
                // Google
                SettingsTile(
              icon: Icons.g_mobiledata_outlined,
              iconColor: sec.isGoogleLinked ? Colors.green.shade600 : null,
              label: sec.isGoogleLinked ? 'Google vinculado' : 'Vincular Google',
              trailing: sec.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : sec.isGoogleLinked
                      ? Icon(Icons.check_circle_outlined, color: Colors.green.shade600, size: 20)
                      : null,
              onTap: sec.isGoogleLinked ? null : () => ref.read(securityProvider.notifier).linkGoogle(),
            ),

            const Divider(height: 1, color: Color(0xFFF5F0EB)),

            // Email
            SettingsTile(
              icon: Icons.email_outlined,
              iconColor: sec.isEmailConfirmed ? Colors.green.shade600 : sec.isEmailAdded ? Colors.orange.shade600 : null,
              label: sec.isEmailAdded ? (sec.email ?? 'Email agregado') : 'Agregar email',
              trailing: sec.isEmailConfirmed
                  ? Icon(Icons.check_circle_outlined, color: Colors.green.shade600, size: 20)
                  : sec.isEmailAdded
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                          ),
                          child: Text(
                            'Verificar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        )
                      : null,
              onTap: sec.isEmailAdded ? null : () => _showEmailSheet(context),
            ),

            const Divider(height: 1, color: Color(0xFFF5F0EB)),

            // Password
            if (sec.hasPassword)
              SettingsTile(
                icon: Icons.lock_outlined,
                iconColor: Colors.green.shade600,
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
                    Icon(Icons.check_circle_outlined, color: Colors.green.shade600, size: 20),
                  ],
                ),
                onTap: () => _showPasswordSheet(context),
              )
            else
              SettingsTile(
                icon: Icons.lock_open_outlined,
                iconColor: _canAddPassword(sec) ? Colors.orange.shade600 : Colors.red.shade400,
                label: 'Agregar contrasena',
                trailing: !_canAddPassword(sec)
                    ? Text(
                        sec.isEmailAdded ? 'Confirma email' : 'Requiere email',
                        style: textTheme.bodySmall?.copyWith(color: Colors.red.shade400, fontSize: 11),
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

          // ── Dispositivos ──
          _animated(1, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Dispositivos'),

              _buildCard(cs, ext, children: [
                SettingsTile(
                  icon: Icons.devices_outlined,
                  label: 'Dispositivos conectados',
                  onTap: () => context.push('/devices'),
                ),
                const Divider(height: 1, color: Color(0xFFF5F0EB)),
                SettingsTile(
                  icon: Icons.qr_code_scanner_outlined,
                  label: 'Vincular sesion web',
                  onTap: () => context.push('/qr-scan'),
                ),
              ]),
            ],
          )),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Acerca de ──
          _animated(2, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: 'Acerca de'),

              _buildCard(cs, ext, children: [
            // Update button (only if newer build available)
            if (UpdaterService.instance.apkUpdateAvailable) ...[
              SettingsTile(
                icon: Icons.system_update_outlined,
                iconColor: Colors.blue.shade600,
                label: 'Actualizar a ${UpdaterService.instance.apkUpdateVersion}',
                trailing: Icon(Icons.download_outlined, color: Colors.blue.shade600, size: 20),
                onTap: () => _launchUpdate(),
              ),
              const Divider(height: 1, color: Color(0xFFF5F0EB)),
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
            const Divider(height: 1, color: Color(0xFFF5F0EB)),

            SettingsTile(
              icon: Icons.refresh_outlined,
              iconColor: Colors.teal,
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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                    foregroundColor: Colors.white,
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
                      hintText: 'Contrasena (min. 6 caracteres)',
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
                        if (pass.length < 6) {
                          ToastService.showError('La contrasena debe tener al menos 6 caracteres');
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
                        foregroundColor: Colors.white,
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
