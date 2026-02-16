import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme_extension.dart';

enum BCButtonVariant { primary, outline, gold }

class BCButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BCButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;

  const BCButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = BCButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == BCButtonVariant.primary;
    final isGold = variant == BCButtonVariant.gold;
    final isOutline = variant == BCButtonVariant.outline;
    final isDisabled = onPressed == null && !loading;

    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Container(
        decoration: isPrimary
            ? BoxDecoration(
                gradient: ext.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: !isDisabled
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              )
            : isGold
                ? BoxDecoration(
                    gradient: ext.accentGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: !isDisabled
                        ? [
                            BoxShadow(
                              color: colorScheme.secondary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  )
                : BoxDecoration(
                    border: Border.all(
                      color: isDisabled
                          ? colorScheme.onSurface.withValues(alpha: 0.5)
                          : colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.transparent,
                  ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading || isDisabled
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed?.call();
                  },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: loading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isOutline ? colorScheme.primary : Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            color: isDisabled
                                ? colorScheme.onSurface.withValues(alpha: 0.5)
                                : isOutline
                                    ? colorScheme.primary
                                    : isGold
                                        ? colorScheme.onSurface
                                        : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: isDisabled
                                    ? colorScheme.onSurface.withValues(alpha: 0.5)
                                    : isOutline
                                        ? colorScheme.primary
                                        : isGold
                                            ? colorScheme.onSurface
                                            : Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
