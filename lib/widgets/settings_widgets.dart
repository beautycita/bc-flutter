import 'package:flutter/material.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';

/// Reusable section header for settings sub-screens.
class SectionHeader extends StatelessWidget {
  final String label;
  const SectionHeader({super.key, required this.label});

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

/// Reusable settings tile with icon, label, optional trailing widget.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
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
                color: iconColor ?? BeautyCitaTheme.primaryRose,
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

/// Option row used in bottom sheets (transport, price, etc.).
class OptionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const OptionTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BeautyCitaTheme.textLight,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: BeautyCitaTheme.primaryRose,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet drag handle + title helper.
Widget buildSheetHeader(BuildContext context, String title) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
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
      const SizedBox(height: 16),
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      const SizedBox(height: 16),
    ],
  );
}
