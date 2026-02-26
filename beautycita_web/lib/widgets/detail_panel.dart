import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

import '../config/breakpoints.dart';

/// Right-side detail panel that displays information about a selected item.
///
/// On desktop (>1200px): a 400px-wide panel inline beside the table.
/// On tablet (800–1200px): a modal overlay with a scrim.
/// On mobile (<800px): a full-screen modal with a back button.
///
/// This widget handles only the **content chrome** (header, actions, scroll).
/// The caller wraps it in the appropriate presentation mode via
/// [MasterDetailLayout].
class DetailPanel extends StatelessWidget {
  const DetailPanel({
    required this.title,
    required this.onClose,
    required this.child,
    this.actions = const [],
    super.key,
  });

  /// Panel header text.
  final String title;

  /// Called when the user taps the close / back button.
  final VoidCallback onClose;

  /// Action buttons rendered in the header row (edit, delete, etc.).
  final List<Widget> actions;

  /// The scrollable detail content.
  final Widget child;

  /// Show the detail panel as a modal overlay (tablet) or full-screen (mobile).
  ///
  /// Returns when the user closes the panel.
  static Future<void> showAsModal(
    BuildContext context, {
    required String title,
    required VoidCallback onClose,
    required Widget child,
    List<Widget> actions = const [],
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = WebBreakpoints.isMobile(width);

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close detail',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return Align(
          alignment: isMobile ? Alignment.center : Alignment.centerRight,
          child: Material(
            elevation: 8,
            borderRadius: isMobile
                ? BorderRadius.zero
                : const BorderRadius.horizontal(
                    left: Radius.circular(BCSpacing.radiusMd),
                  ),
            child: SizedBox(
              width: isMobile ? double.infinity : 480,
              height: double.infinity,
              child: DetailPanel(
                title: title,
                onClose: () {
                  Navigator.of(ctx).pop();
                  onClose();
                },
                actions: actions,
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, panel) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));

        return SlideTransition(position: slide, child: panel);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.md,
              vertical: BCSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                  ),
                ),
                const SizedBox(width: BCSpacing.sm),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Action buttons
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: BCSpacing.sm),
                  ...actions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(left: BCSpacing.xs),
                      child: action,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BCSpacing.md),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
