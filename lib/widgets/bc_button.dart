import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

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

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Container(
        decoration: isPrimary
            ? BoxDecoration(
                gradient: BeautyCitaTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: !isDisabled
                    ? [
                        BoxShadow(
                          color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              )
            : isGold
                ? BoxDecoration(
                    gradient: BeautyCitaTheme.accentGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: !isDisabled
                        ? [
                            BoxShadow(
                              color: BeautyCitaTheme.secondaryGold.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  )
                : BoxDecoration(
                    border: Border.all(
                      color: isDisabled
                          ? BeautyCitaTheme.textLight
                          : BeautyCitaTheme.primaryRose,
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
                          color: isOutline ? BeautyCitaTheme.primaryRose : Colors.white,
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
                                ? BeautyCitaTheme.textLight
                                : isOutline
                                    ? BeautyCitaTheme.primaryRose
                                    : isGold
                                        ? BeautyCitaTheme.textDark
                                        : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: isDisabled
                                    ? BeautyCitaTheme.textLight
                                    : isOutline
                                        ? BeautyCitaTheme.primaryRose
                                        : isGold
                                            ? BeautyCitaTheme.textDark
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
