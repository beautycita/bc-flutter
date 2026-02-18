import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';
import 'palettes.dart';
import 'theme_extension.dart';

/// Builds a complete ThemeData from a BCPalette.
/// This is the SINGLE source of truth for all theme generation.
ThemeData buildThemeFromPalette(BCPalette palette, {double fontScale = 1.0, double? radiusOverride}) {
  final isLight = palette.brightness == Brightness.light;
  final base = isLight ? ThemeData.light() : ThemeData.dark();

  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    surface: palette.surface,
    onSurface: palette.onSurface,
    error: palette.error,
    onError: palette.onError,
  );

  // Scaled dimensions
  final s = palette.spacingScale;
  final r = radiusOverride ?? palette.radiusScale;
  final f = fontScale;

  final headingColor = palette.textPrimary;
  final bodyColor = palette.textPrimary;
  final hintColor = palette.textSecondary;

  // Dynamic font lookup — each theme gets its own typography personality
  TextStyle heading({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double height = 1.3,
  }) =>
      GoogleFonts.getFont(
        palette.headingFont,
        fontSize: fontSize * f,
        fontWeight: fontWeight,
        color: color ?? headingColor,
        height: height,
      );

  TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.5,
  }) =>
      GoogleFonts.getFont(
        palette.bodyFont,
        fontSize: fontSize * f,
        fontWeight: fontWeight,
        color: color ?? bodyColor,
        height: height,
      );

  final textTheme = base.textTheme.copyWith(
    displayLarge: heading(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
    displayMedium: heading(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
    displaySmall: heading(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
    headlineLarge: heading(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
    headlineMedium: heading(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    headlineSmall: heading(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
    titleLarge: body(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
    titleMedium: body(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall: body(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: body(fontSize: 16, height: 1.5),
    bodyMedium: body(fontSize: 14, height: 1.5),
    bodySmall: body(fontSize: 12, color: hintColor, height: 1.5),
    labelLarge: body(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
    labelMedium: body(fontSize: 14, fontWeight: FontWeight.w500, height: 1.2),
    labelSmall: body(fontSize: 12, fontWeight: FontWeight.w500, color: hintColor, height: 1.2),
  );

  final rMD = AppConstants.radiusMD * r;
  final rLG = AppConstants.radiusLG * r;
  final rXL = AppConstants.radiusXL * r;

  final ext = BCThemeExtension(
    primaryGradient: palette.primaryGradient,
    accentGradient: palette.accentGradient,
    goldGradientStops: palette.goldGradientStops,
    goldGradientPositions: palette.goldGradientPositions,
    categoryColors: palette.categoryColors,
    blurSigma: palette.blurSigma,
    glassTint: palette.glassTint,
    glassBorderOpacity: palette.glassBorderOpacity,
    cinematicPrimary: palette.cinematicPrimary,
    cinematicAccent: palette.cinematicAccent,
    cinematicGradient: palette.cinematicGradient,
    spacingScale: palette.spacingScale,
    radiusScale: palette.radiusScale,
    headingFont: palette.headingFont,
    bodyFont: palette.bodyFont,
    statusBarColor: palette.statusBarColor,
    statusBarIconBrightness: palette.statusBarIconBrightness,
    navigationBarColor: palette.navigationBarColor,
    navigationBarIconBrightness: palette.navigationBarIconBrightness,
    cardBorderColor: palette.cardBorderColor,
    shimmerColor: palette.shimmerColor,
    successColor: palette.success,
    warningColor: palette.warning,
    infoColor: palette.info,
    statusPending: palette.statusPending,
    statusConfirmed: palette.statusConfirmed,
    statusCompleted: palette.statusCompleted,
    statusCancelled: palette.statusCancelled,
    chartColors: palette.chartColors,
    chartGridColor: palette.chartGridColor,
    chartLabelColor: palette.chartLabelColor,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.scaffoldBackground,
    extensions: [ext],

    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: palette.scaffoldBackground,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: heading(fontSize: 20, fontWeight: FontWeight.w600, color: palette.textPrimary),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
    ),

    cardTheme: CardThemeData(
      elevation: AppConstants.elevationLow,
      color: palette.cardColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rMD),
      ),
      margin: EdgeInsets.all(AppConstants.paddingMD * s),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: AppConstants.elevationMedium,
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        minimumSize: const Size(double.infinity, AppConstants.minTouchHeight),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingXL * s,
          vertical: AppConstants.paddingMD * s,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLG),
        ),
        textStyle: body(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size(double.infinity, AppConstants.minTouchHeight),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingXL * s,
          vertical: AppConstants.paddingMD * s,
        ),
        side: BorderSide(color: palette.primary, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLG),
        ),
        textStyle: body(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size(AppConstants.minTouchHeight, AppConstants.minTouchHeight),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLG * s,
          vertical: AppConstants.paddingMD * s,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rMD),
        ),
        textStyle: body(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG * s,
        vertical: AppConstants.paddingMD * s,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide(color: palette.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide(color: palette.error, width: 2),
      ),
      labelStyle: body(fontSize: 16, color: palette.textSecondary),
      hintStyle: body(fontSize: 16, color: palette.textSecondary),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      elevation: AppConstants.elevationHigh,
      backgroundColor: palette.scaffoldBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(rXL)),
      ),
      modalBackgroundColor: palette.scaffoldBackground,
      modalElevation: AppConstants.elevationHigh,
    ),

    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: AppConstants.paddingMD * s,
    ),

    iconTheme: IconThemeData(color: palette.textPrimary, size: 24),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: AppConstants.elevationMedium,
      backgroundColor: palette.secondary,
      foregroundColor: palette.onSecondary,
      shape: const CircleBorder(),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      deleteIconColor: palette.textPrimary,
      disabledColor: palette.divider,
      selectedColor: palette.primary,
      secondarySelectedColor: palette.secondary,
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD * s,
        vertical: AppConstants.paddingSM * s,
      ),
      labelStyle: body(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
      secondaryLabelStyle: body(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rMD),
      ),
    ),
  );
}

// ─── Legacy static access (for migration period) ─────────────────────────
// After all files are converted, this class can be deleted.
// During migration, screens can use EITHER the old statics OR Theme.of(context).
class BeautyCitaTheme {
  // Brand Colors — point at Rose & Gold palette
  static const Color primaryRose = Color(0xFFC2185B);
  static const Color secondaryGold = Color(0xFFFFB300);
  static const Color surfaceCream = Color(0xFFFFF8F0);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFEEEEEE);

  static const Color primaryRoseLight = Color(0xFFFCE4EC);
  static const Color secondaryGoldLight = Color(0xFFFFF8E1);
  static const Color accentTeal = Color(0xFF00897B);
  static const Color accentTealLight = Color(0xFFE0F2F1);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRose, Color(0xFFD81B60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryGold, Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Spacing/radius/elevation — still delegate to AppConstants
  static const double radiusSmall = AppConstants.radiusSM;
  static const double radiusMedium = AppConstants.radiusMD;
  static const double radiusLarge = AppConstants.radiusLG;
  static const double radiusXL = AppConstants.radiusXL;
  static const double spaceXS = AppConstants.paddingXS;
  static const double spaceSM = AppConstants.paddingSM;
  static const double spaceMD = AppConstants.paddingMD;
  static const double spaceLG = AppConstants.paddingLG;
  static const double spaceXL = AppConstants.paddingXL;
  static const double spaceXXL = AppConstants.paddingXXL;
  static const double minTouchTarget = AppConstants.minTouchHeight;
  static const double largeTouchTarget = AppConstants.largeTouchHeight;
  static const double elevationCard = AppConstants.elevationLow;
  static const double elevationButton = AppConstants.elevationMedium;
  static const double elevationSheet = AppConstants.elevationHigh;

  /// Legacy getter — returns Rose & Gold theme.
  /// New code should use buildThemeFromPalette() via themeProvider.
  static ThemeData get lightTheme => buildThemeFromPalette(roseGoldPalette);
}
