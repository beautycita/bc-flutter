import 'package:flutter/material.dart';
import '../config/web_theme.dart';

/// Single source of truth for "you're in the demo, this would persist in
/// production" UX. Use anywhere a write action would otherwise call
/// Supabase and 401/RLS-fail with an ugly red toast.
///
/// Returns true when the caller should proceed (we're not in demo);
/// returns false when the caller should bail (a friendly demo dialog
/// has already been shown to the user).
class DemoActionGuard {
  /// If [isDemo] is true, show the demo-mode dialog and return false so
  /// the caller short-circuits its real write path. If false, return
  /// true so the caller proceeds to its production path.
  ///
  /// [actionLabel] is what we'd be doing in prod, framed as a verb-noun
  /// (e.g. "crear esta tarjeta de regalo", "enviar la invitacion").
  static Future<bool> intercept(
    BuildContext context, {
    required bool isDemo,
    required String actionLabel,
  }) async {
    if (!isDemo) return true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DemoModeDialog(actionLabel: actionLabel),
    );
    return false;
  }
}

class _DemoModeDialog extends StatelessWidget {
  final String actionLabel;
  const _DemoModeDialog({required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: kWebBrandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Modo demostracion',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: kWebTextPrimary,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: kWebTextSecondary,
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Estas explorando el panel de negocio en modo demostracion. '
                'No vamos a $actionLabel sobre esta cuenta de prueba — para '
                'que tu salon trabaje con datos reales, registralo en '
                'BeautyCita.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: kWebTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kWebPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
