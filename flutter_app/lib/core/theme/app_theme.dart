import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryCyan = Color(0xFF00F5FF);
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color accentPurple = Color(0xFF8B00FF);
  static const Color backgroundDark = Color(0xFF050A14);
  static const Color surfaceDark = Color(0xFF0D1B2A);
  static const Color surfaceMid = Color(0xFF112240);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassWhiteStrong = Color(0x33FFFFFF);
  static const Color textPrimary = Color(0xFFECF0F1);
  static const Color textSecondary = Color(0xFF8899AA);
  static const Color errorRed = Color(0xFFFF4757);
  static const Color warningAmber = Color(0xFFFFBE0B);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: accentGreen,
      tertiary: accentPurple,
      surface: surfaceDark,
      error: errorRed,
      onPrimary: backgroundDark,
      onSecondary: backgroundDark,
      onSurface: textPrimary,
    ),
    fontFamily: 'Rajdhani',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 2,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 1.5,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryCyan,
        letterSpacing: 1,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: textSecondary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryCyan,
        letterSpacing: 1,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: primaryCyan),
      titleTextStyle: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 1,
      ),
    ),
    cardTheme: CardTheme(
      color: surfaceMid,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: glassWhite, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryCyan,
        foregroundColor: backgroundDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryCyan,
        side: const BorderSide(color: primaryCyan, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconTheme: const IconThemeData(color: primaryCyan, size: 24),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glassWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: glassWhiteStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: glassWhite),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryCyan, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
      prefixIconColor: primaryCyan,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: primaryCyan,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: glassWhite,
      labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
      side: const BorderSide(color: glassWhiteStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryCyan,
      linearTrackColor: glassWhite,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: primaryCyan,
      inactiveTrackColor: glassWhite,
      thumbColor: primaryCyan,
      overlayColor: Color(0x2900F5FF),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primaryCyan : textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? const Color(0x4400F5FF) : glassWhite,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: glassWhite,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceMid,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class AppColors {
  static const cyan = AppTheme.primaryCyan;
  static const blue = AppTheme.primaryBlue;
  static const green = AppTheme.accentGreen;
  static const orange = AppTheme.accentOrange;
  static const purple = AppTheme.accentPurple;
  static const background = AppTheme.backgroundDark;
  static const surface = AppTheme.surfaceDark;
  static const surfaceMid = AppTheme.surfaceMid;
  static const glass = AppTheme.glassWhite;
  static const glassStrong = AppTheme.glassWhiteStrong;
  static const textPrimary = AppTheme.textPrimary;
  static const textSecondary = AppTheme.textSecondary;
  static const error = AppTheme.errorRed;
  static const warning = AppTheme.warningAmber;

  static const List<Color> scannerGradient = [
    Color(0xFF00F5FF),
    Color(0xFF0066FF),
  ];

  static const List<Color> heatGradient = [
    Color(0xFF0066FF),
    Color(0xFF00FF88),
    Color(0xFFFFBE0B),
    Color(0xFFFF4757),
  ];

  static const List<Color> holographicGradient = [
    Color(0xFF00F5FF),
    Color(0xFF8B00FF),
    Color(0xFF0066FF),
  ];
}
