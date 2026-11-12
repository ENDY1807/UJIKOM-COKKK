import 'package:flutter/material.dart';
export '../services/app_localization.dart';

class AppTheme {
  // Brand Palette: Orange and White
  static const Color orangePrimary = Color(0xFFEA580C); // Vibrant warm culinary orange
  static const Color orangeHover = Color(0xFFC2410C);
  static const Color orangeLight = Color(0xFFFFF7ED); // Soft warm background
  static const Color orangeBorder = Color(0xFFFED7AA);

  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceBg = Color(0xFFFAFAF9); // Warm off-white
  static const Color surfaceCard = Color(0xFFFFFFFF);

  // High contrast text (WCAG AA compliant > 4.5:1 against white & light orange)
  static const Color textDark = Color(0xFF1E293B); // Slate 800
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200

  // Semantic Status Colors
  static const Color statusGreen = Color(0xFF16A34A);
  static const Color statusGreenBg = Color(0xFFF0FDF4);
  static const Color statusBlue = Color(0xFF2563EB);
  static const Color statusBlueBg = Color(0xFFEFF6FF);
  static const Color statusAmber = Color(0xFFD97706);
  static const Color statusAmberBg = Color(0xFFFFFBEB);
  static const Color statusRed = Color(0xFFDC2626);
  static const Color statusRedBg = Color(0xFFFEF2F2);

  // Deep Luxury Obsidian Dark Mode Palette
  static const Color darkBg = Color(0xFF090A0C); // Ultra-deep rich obsidian black
  static const Color darkSurface = Color(0xFF121418); // Elevated matte card black
  static const Color darkBorder = Color(0xFF22262E); // Crisp, subtle futuristic border
  static const Color darkFill = Color(0xFF181B21); // Elevated input & interactive surface
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Pure crisp high-contrast text
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Muted slate text

  // Luxury Amber-Orange Accent
  static const Color orangeAccent = Color(0xFFFF6B2B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: orangePrimary,
        onPrimary: white,
        primaryContainer: orangeLight,
        onPrimaryContainer: orangePrimary,
        surface: surfaceCard,
        onSurface: textDark,
        error: statusRed,
        onError: white,
      ),
      scaffoldBackgroundColor: surfaceBg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orangePrimary,
          foregroundColor: white,
          minimumSize: const Size(88, 46), // Touch target >= 44px (R-03)
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDark,
          minimumSize: const Size(88, 46),
          side: const BorderSide(color: borderSubtle, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: orangePrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textMuted, fontSize: 13),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: orangePrimary,
        onPrimary: white,
        primaryContainer: Color(0xFF431407),
        onPrimaryContainer: Color(0xFFFFEDD5),
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: statusRed,
        onError: white,
      ),
      scaffoldBackgroundColor: darkBg,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkTextPrimary),
        displayMedium: TextStyle(color: darkTextPrimary),
        displaySmall: TextStyle(color: darkTextPrimary),
        headlineLarge: TextStyle(color: darkTextPrimary),
        headlineMedium: TextStyle(color: darkTextPrimary),
        headlineSmall: TextStyle(color: darkTextPrimary),
        titleLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: darkTextPrimary),
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary),
        labelLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        labelMedium: TextStyle(color: darkTextSecondary),
        labelSmall: TextStyle(color: darkTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: darkTextSecondary, fontSize: 13),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orangePrimary,
          foregroundColor: white,
          minimumSize: const Size(88, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get surfaceCard => isDarkMode ? AppTheme.darkSurface : Colors.white;
  Color get surfaceBg => isDarkMode ? AppTheme.darkBg : const Color(0xFFFAFAF9);
  Color get textPrimary => isDarkMode ? AppTheme.darkTextPrimary : const Color(0xFF1E293B);
  Color get textSecondary => isDarkMode ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
  Color get borderSubtle => isDarkMode ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
  Color get fillSubtle => isDarkMode ? AppTheme.darkFill : const Color(0xFFF1F5F9);
}
