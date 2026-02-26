/// Layout constants: spacing, radius, elevation, avatar sizes, touch targets,
/// grid dimensions, bottom-sheet metrics, and opacity values.
///
/// Each app applies these via its own ThemeData / layout widgets.
abstract final class BCSpacing {
  // ── Padding ──────────────────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ── Screen margins ───────────────────────────────────────────────────────
  static const double screenHorizontal = 20.0;
  static const double screenVertical = 16.0;

  // ── Grid & card spacing ──────────────────────────────────────────────────
  static const double gridSpacing = 12.0;
  static const double cardSpacing = 16.0;
  static const int gridCrossAxisCount = 2;
  static const double gridChildAspectRatio = 0.85;

  // ── Touch targets (thumb-zone friendly) ──────────────────────────────────
  static const double thumbZoneStart = 0.4;
  static const double thumbZoneHeight = 0.6;
  static const double minTouchHeight = 56.0;
  static const double comfortableTouchHeight = 64.0;
  static const double largeTouchHeight = 72.0;
  static const double iconTouchTarget = 48.0;

  // ── Border radius ────────────────────────────────────────────────────────
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 999.0;

  // ── Elevation ────────────────────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationXHigh = 16.0;

  // ── Icon sizes ───────────────────────────────────────────────────────────
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconXxl = 64.0;

  // ── Avatar / image sizes ─────────────────────────────────────────────────
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 96.0;

  // ── Category card sizes ──────────────────────────────────────────────────
  static const double categoryCardHeight = 140.0;
  static const double categoryIconSize = 56.0;

  // ── Bottom sheet ─────────────────────────────────────────────────────────
  static const double bottomSheetMaxHeight = 0.85;
  static const double bottomSheetDragHandleWidth = 40.0;
  static const double bottomSheetDragHandleHeight = 4.0;
  static const double bottomSheetDragHandleRadius = 2.0;

  // ── Opacity ──────────────────────────────────────────────────────────────
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.6;
  static const double opacityLight = 0.87;
}
