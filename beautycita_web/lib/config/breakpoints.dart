/// Responsive breakpoints for the web app.
/// Desktop-first: design for >1200px, then adapt down.
abstract final class WebBreakpoints {
  /// Full three-column layout (sidebar + content + detail panel)
  static const double desktop = 1200;

  /// Collapsed sidebar, content + detail overlay
  static const double tablet = 800;

  /// Helper to check current width category
  static bool isDesktop(double width) => width >= desktop;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isMobile(double width) => width < tablet;
}
