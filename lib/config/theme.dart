import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BeautyCitaTheme {
  // Brand Colors
  static const Color primaryRose = Color(0xFFC2185B);
  static const Color secondaryGold = Color(0xFFFFB300);
  static const Color surfaceCream = Color(0xFFFFF8F0);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFEEEEEE);

  // Gradients
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

  // Border Radius
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXL = 32.0;

  // Spacing
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // Touch targets (thumb-friendly minimum)
  static const double minTouchTarget = 56.0;
  static const double largeTouchTarget = 72.0;

  // Elevation
  static const double elevationCard = 2.0;
  static const double elevationButton = 4.0;
  static const double elevationSheet = 8.0;

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primaryRose,
        onPrimary: Colors.white,
        secondary: secondaryGold,
        onSecondary: textDark,
        surface: surfaceCream,
        onSurface: textDark,
        error: Color(0xFFD32F2F),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundWhite,

      // Typography
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textDark,
          height: 1.2,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textDark,
          height: 1.2,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.4,
        ),
        titleSmall: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textDark,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textDark,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textLight,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.2,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
          height: 1.2,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textLight,
          height: 1.2,
        ),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: backgroundWhite,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        iconTheme: const IconThemeData(
          color: textDark,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: elevationCard,
        color: surfaceCream,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        margin: const EdgeInsets.all(spaceMD),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevationButton,
          backgroundColor: primaryRose,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXL,
            vertical: spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryRose,
          minimumSize: const Size(double.infinity, minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXL,
            vertical: spaceMD,
          ),
          side: const BorderSide(color: primaryRose, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryRose,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: spaceLG,
            vertical: spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceLG,
          vertical: spaceMD,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryRose, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        labelStyle: GoogleFonts.nunito(
          fontSize: 16,
          color: textLight,
        ),
        hintStyle: GoogleFonts.nunito(
          fontSize: 16,
          color: textLight,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        elevation: elevationSheet,
        backgroundColor: backgroundWhite,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXL),
          ),
        ),
        modalBackgroundColor: backgroundWhite,
        modalElevation: elevationSheet,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerLight,
        thickness: 1,
        space: spaceMD,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: textDark,
        size: 24,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: elevationButton,
        backgroundColor: secondaryGold,
        foregroundColor: textDark,
        shape: CircleBorder(),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: surfaceCream,
        deleteIconColor: textDark,
        disabledColor: dividerLight,
        selectedColor: primaryRose,
        secondarySelectedColor: secondaryGold,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMD,
          vertical: spaceSM,
        ),
        labelStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        secondaryLabelStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    );
  }
}
