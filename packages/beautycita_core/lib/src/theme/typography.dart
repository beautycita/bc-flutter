/// Typography font-family names and animation durations shared across apps.
///
/// Each app builds its own TextTheme / ThemeData from these constants.
abstract final class BCTypography {
  // ── Default font families ────────────────────────────────────────────────
  // These match the BCPalette defaults for the Rose & Gold palette.
  static const String defaultHeadingFont = 'Poppins';
  static const String defaultBodyFont = 'Nunito';

  // ── Animation durations ──────────────────────────────────────────────────
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration bottomSheetAnimation = Duration(milliseconds: 400);
  static const Duration shimmerAnimation = Duration(milliseconds: 1500);

  // ── Debounce / throttle ──────────────────────────────────────────────────
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration tapDebounce = Duration(milliseconds: 300);

  // ── Timeouts ─────────────────────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration authTimeout = Duration(seconds: 15);

  // ── Cache durations ──────────────────────────────────────────────────────
  static const Duration cacheDurationShort = Duration(minutes: 5);
  static const Duration cacheDurationMedium = Duration(hours: 1);
  static const Duration cacheDurationLong = Duration(days: 1);

  // ── Pagination ───────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ── Image quality ────────────────────────────────────────────────────────
  static const int imageQualityLow = 50;
  static const int imageQualityMedium = 75;
  static const int imageQualityHigh = 90;
}
