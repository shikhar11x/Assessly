import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Light: warm neutral with charcoal primary. Dark: GitHub-style grey. Green is only an accent.
class AppTheme {
  static const String fontFamily = 'Inter';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final primary = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF292524);
    final onPrimary = isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);

    final scheme = ColorScheme.fromSeed(seedColor: c.success, brightness: b).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: c.textSecondary,
      tertiary: c.success,
      onTertiary: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.border,
      error: c.danger,
      primaryContainer: c.secondarySurface,
      onPrimaryContainer: c.text,
      secondaryContainer: c.secondarySurface,
      onSecondaryContainer: c.text,
      tertiaryContainer: c.success.withValues(alpha: 0.15),
      onTertiaryContainer: c.success,
      errorContainer: c.danger.withValues(alpha: 0.12),
      onErrorContainer: c.danger,
      surfaceContainerHighest: c.secondarySurface,
    );

    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.controlRadius));
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
      borderSide: BorderSide(color: c.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      extensions: [c],
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: c.text),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: c.text),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.text),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text),
        bodyLarge: TextStyle(fontSize: 15, color: c.text),
        bodyMedium: TextStyle(fontSize: 14, color: c.text),
        bodySmall: TextStyle(fontSize: 12, color: c.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: AppSpacing.navbarHeight,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          side: BorderSide(color: c.border),
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: controlShape, minimumSize: const Size(48, AppSpacing.buttonHeight)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: c.danger),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: c.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: controlShape),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? (Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light);
}
