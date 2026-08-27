import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// نظام الثيمات الكامل لتطبيق العربية للكريستال
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildLightTheme();
  static ThemeData get darkTheme => _buildDarkTheme();

  static const String _fontFamily = 'Cairo';
  static const String _fontFamilyEn = 'Poppins';

  // الثيم الفاتح
  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.background,
    );

    return _buildTheme(colorScheme, isDark: false);
  }

  // الثيم الداكن
  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.secondary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.darkBackground,
    );

    return _buildTheme(colorScheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, {required bool isDark}) {
    final primaryColor = colorScheme.primary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.background;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: bgColor,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w900, color: textColor),
        displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800, color: textColor),
        displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700, color: textColor),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700, color: textColor),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700, color: textColor),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600, color: textColor),
        titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600, color: textColor),
        titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600, color: textColor),
        titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500, color: textColor),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400, color: textColor),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400, color: textColor),
        bodySmall: base.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600, color: textColor),
        labelSmall: base.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500, color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size.fromHeight(AppConstants.buttonHeight),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceLight : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: AppColors.secondary,
        suffixIconColor: AppColors.secondary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: isDark ? AppColors.darkSurfaceLight : AppColors.surface,
        selectedColor: AppColors.secondary,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        side: BorderSide(
          color: isDark ? AppColors.darkSurfaceLight : AppColors.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgColor,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkSurfaceLight : AppColors.surface,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.secondary,
        circularTrackColor: AppColors.secondary.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textColor,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: bgColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.borderRadius),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textColor,
        unselectedLabelColor: textSecondary,
        indicatorColor: AppColors.secondary,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
      ),
    );
  }

  /// اسم خط اللغة الإنجليزية
  static String get fontFamilyEn => _fontFamilyEn;
}
