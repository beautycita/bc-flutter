/// Responsive breakpoints for the web app.
/// Desktop-first: design for >1200px, then adapt down.
abstract final class WebBreakpoints {
  /// Full three-column layout (sidebar + content + detail panel)
  static const double desktop = 1200;

  /// Two-column content (e.g. staff table + chart side-by-side)
  static const double tabletLarge = 900;

  /// Collapsed sidebar, content + detail overlay
  static const double tablet = 800;

  /// Two-column form fields, split panels
  static const double tabletSmall = 700;

  /// Grid column threshold (e.g. 4-col vs 2-col grids)
  static const double compact = 600;

  /// Narrow mobile — stacked layouts, minimal padding
  static const double mobileSmall = 500;

  /// Ultra-narrow — single-column everything
  static const double mobileXSmall = 480;

  /// Helper to check current width category
  static bool isDesktop(double width) => width >= desktop;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isMobile(double width) => width < tablet;

  /// Finer-grained helpers
  static bool isNarrow(double width) => width < mobileSmall;
  static bool isCompact(double width) => width < compact;
}
