// Admin v2 design tokens.
//
// Single source of truth for admin v2 UI: spacing, type ramp, semantic colors
// derived from the app theme. Every primitive in lib/widgets/admin/v2/ reads
// from here. No raw colors / paddings in primitives.

import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';

import '../../../config/constants.dart';

class AdminV2Tokens {
  AdminV2Tokens._();

  // ── Spacing (alias to AppConstants for consistency with the rest of the app)
  static const double spacingXS = AppConstants.paddingXS; // 4
  static const double spacingSM = AppConstants.paddingSM; // 8
  static const double spacingMD = AppConstants.paddingMD; // 16
  static const double spacingLG = AppConstants.paddingLG; // 24
  static const double spacingXL = AppConstants.paddingXL; // 32

  // ── Radius
  static const double radiusSM = AppConstants.radiusSM; // 12
  static const double radiusMD = AppConstants.radiusMD; // 16
  static const double radiusLG = AppConstants.radiusLG; // 24
  static const double radiusFull = AppConstants.radiusFull;

  // ── Type ramp — admin v2 (Poppins for headings, Nunito for body)
  static TextStyle title(BuildContext c) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Theme.of(c).colorScheme.onSurface,
      );
  static TextStyle subtitle(BuildContext c) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Theme.of(c).colorScheme.onSurface,
      );
  static TextStyle body(BuildContext c) => GoogleFonts.nunito(
        fontSize: 14,
        color: Theme.of(c).colorScheme.onSurface,
      );
  static TextStyle muted(BuildContext c) => GoogleFonts.nunito(
        fontSize: 13,
        color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.6),
      );
  static TextStyle label(BuildContext c) => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(c).colorScheme.primary.withValues(alpha: 0.55),
      );
  static TextStyle kpiNumber(BuildContext c) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Theme.of(c).colorScheme.onSurface,
      );

  // ── Semantic colors
  static Color cardBg(BuildContext c) => Theme.of(c).colorScheme.surface;
  static Color cardBorder(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.08);
  static Color destructive(BuildContext c) => Colors.red.shade600;
  static Color warning(BuildContext c) => Colors.orange.shade700;
  static Color success(BuildContext c) => Colors.green.shade600;
  static Color subtle(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.6);

  // ── Tap target (a11y)
  static const double minTapHeight = 44;
}
