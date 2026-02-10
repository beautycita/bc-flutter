import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/security_provider.dart';
import 'package:beautycita/providers/payment_methods_provider.dart';
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
      ref.read(paymentMethodsProvider.notifier).loadCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sec = ref.watch(securityProvider);
    final textTheme = Theme.of(context).textTheme;

    // Listen for payment method messages
    ref.listen<PaymentMethodsState>(paymentMethodsProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(paymentMethodsProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(paymentMethodsProvider.notifier).clearMessages();
      }
    });

    // Listen for success/error messages
    ref.listen<SecurityState>(securityProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(securityProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(securityProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: BeautyCitaTheme.spaceMD,
        ),
        children: [
          // ── Cuentas vinculadas ──
          const SectionHeader(label: 'Cuentas vinculadas'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

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
            iconColor: sec.isEmailAdded ? Colors.green.shade600 : null,
            label: sec.isEmailAdded ? (sec.email ?? 'Email agregado') : 'Agregar email',
            trailing: sec.isEmailAdded
                ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 20)
                : null,
            onTap: sec.isEmailAdded ? null : () => _showEmailSheet(context),
          ),

          // Password
          SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconColor: sec.hasPassword ? Colors.green.shade600 : null,
            label: sec.hasPassword ? 'Contrasena configurada' : 'Agregar contrasena',
            trailing: sec.hasPassword
                ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 20)
                : !sec.isEmailAdded
                    ? Text(
                        'Requiere email',
                        style: textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight),
                      )
                    : null,
            onTap: sec.hasPassword
                ? null
                : sec.isEmailAdded
                    ? () => _showPasswordSheet(context)
                    : null,
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Dispositivos ──
          const SectionHeader(label: 'Dispositivos'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

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

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Pagos ──
          const SectionHeader(label: 'Metodos de pago'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          _PaymentMethodsSection(ref: ref),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Acerca de ──
          const SectionHeader(label: 'Acerca de'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Version',
            trailing: Text(
              '0.1.0',
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),
        ],
      ),
    );
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
                      color: BeautyCitaTheme.textLight,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Ingresa un email valido'),
                          backgroundColor: Colors.red.shade600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    ref.read(securityProvider.notifier).addEmail(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BeautyCitaTheme.primaryRose,
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

  IconData _cardBrandIcon(String brand) {
    return switch (brand) {
      'visa' => Icons.credit_card,
      'mastercard' => Icons.credit_card,
      'amex' => Icons.credit_card,
      _ => Icons.credit_card,
    };
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
                          color: BeautyCitaTheme.textLight,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('La contrasena debe tener al menos 6 caracteres'),
                              backgroundColor: Colors.red.shade600,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        if (pass != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Las contrasenas no coinciden'),
                              backgroundColor: Colors.red.shade600,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        ref.read(securityProvider.notifier).addPassword(pass);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeautyCitaTheme.primaryRose,
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

// ---------------------------------------------------------------------------
// Payment Methods Section
// ---------------------------------------------------------------------------

class _PaymentMethodsSection extends StatelessWidget {
  final WidgetRef ref;

  const _PaymentMethodsSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final pm = ref.watch(paymentMethodsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Saved cards
        if (pm.isLoading && pm.cards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (pm.cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSM,
              vertical: AppConstants.paddingSM,
            ),
            child: Text(
              'No tienes tarjetas guardadas',
              style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
            ),
          )
        else
          ...pm.cards.map((card) => _CardTile(card: card, ref: ref)),

        // Add card button
        SettingsTile(
          icon: Icons.add_card_rounded,
          label: 'Agregar tarjeta',
          trailing: pm.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: pm.isLoading ? null : () => ref.read(paymentMethodsProvider.notifier).addCard(),
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  final SavedCard card;
  final WidgetRef ref;

  const _CardTile({required this.card, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SettingsTile(
      icon: Icons.credit_card_rounded,
      iconColor: Colors.green.shade600,
      label: '${card.displayBrand} ****${card.last4}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.expiry,
            style: textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmRemove(context),
            child: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade400),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) async {
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
                buildSheetHeader(context, 'Eliminar tarjeta?'),
                Text(
                  '${card.displayBrand} terminada en ${card.last4}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: BeautyCitaTheme.textLight,
                      ),
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
                          'Eliminar',
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
      ref.read(paymentMethodsProvider.notifier).removeCard(card.id);
    }
  }
}
