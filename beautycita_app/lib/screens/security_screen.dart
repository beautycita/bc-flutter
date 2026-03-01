import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/security_provider.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(securityProvider.notifier).checkIdentities();
    });
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
          const SectionHeader(label: 'Cuentas vinculadas'),
          const SizedBox(height: AppConstants.paddingXS),

          // Google
          SettingsTile(
            icon: Icons.g_mobiledata_rounded,
            iconColor: sec.isGoogleLinked ? Colors.green.shade600 : null,
            label: sec.isGoogleLinked ? 'Google vinculado' : 'Vincular Google',
            trailing: sec.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : sec.isGoogleLinked
                    ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 20)
                    : null,
            onTap: sec.isGoogleLinked ? null : () => ref.read(securityProvider.notifier).linkGoogle(),
          ),

          // Email
          SettingsTile(
            icon: Icons.email_outlined,
            iconColor: sec.isEmailConfirmed ? Colors.green.shade600 : sec.isEmailAdded ? Colors.orange.shade600 : null,
            label: sec.isEmailAdded ? (sec.email ?? 'Email agregado') : 'Agregar email',
            trailing: sec.isEmailConfirmed
                ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 20)
                : sec.isEmailAdded
                    ? Text(
                        'Pendiente',
                        style: textTheme.bodySmall?.copyWith(color: Colors.orange.shade600),
                      )
                    : null,
            onTap: sec.isEmailAdded ? null : () => _showEmailSheet(context),
          ),

          // Password
          if (sec.hasPassword)
            SettingsTile(
              icon: Icons.lock_rounded,
              iconColor: Colors.green.shade600,
              label: 'Protegida',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'cambiar',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                ],
              ),
              onTap: () => _showPasswordSheet(context),
            )
          else
            SettingsTile(
              icon: Icons.lock_open_rounded,
              iconColor: _canAddPassword(sec) ? Colors.orange.shade600 : Colors.red.shade400,
              label: 'Agregar contrasena',
              trailing: !_canAddPassword(sec)
                  ? Text(
                      sec.isEmailAdded ? 'Confirma email' : 'Requiere email',
                      style: textTheme.bodySmall?.copyWith(color: Colors.red.shade400, fontSize: 11),
                    )
                  : Icon(Icons.chevron_right, size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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

          const SizedBox(height: AppConstants.paddingLG),

          // ── Dispositivos ──
          const SectionHeader(label: 'Dispositivos'),
          const SizedBox(height: AppConstants.paddingXS),

          SettingsTile(
            icon: Icons.devices_rounded,
            label: 'Dispositivos conectados',
            onTap: () => context.push('/devices'),
          ),
          SettingsTile(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Vincular sesion web',
            onTap: () => context.push('/qr-scan'),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Acerca de ──
          const SectionHeader(label: 'Acerca de'),
          const SizedBox(height: AppConstants.paddingXS),

          SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Version',
            trailing: Text(
              '0.1.0',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }

  /// Google users can always add a password (email verified by Google).
  /// Email-only users need confirmed email first.
  bool _canAddPassword(SecurityState sec) {
    if (sec.isGoogleLinked) return true;
    return sec.isEmailConfirmed;
  }

  void _showEmailSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
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

    showModalBottomSheet(
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
