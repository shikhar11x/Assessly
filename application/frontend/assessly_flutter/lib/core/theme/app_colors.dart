import 'package:flutter/material.dart';

/// Design-system colours that are not part of Material's ColorScheme.
/// Read with: `Theme.of(context).extension<AppColors>()!`
class AppColors extends ThemeExtension<AppColors> {
  final Color canvas;
  final Color surface;
  final Color sidebar;
  final Color secondarySurface;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;

  const AppColors({
    required this.canvas,
    required this.surface,
    required this.sidebar,
    required this.secondarySurface,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const light = AppColors(
    canvas: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    sidebar: Color(0xFFF5F5F4),
    secondarySurface: Color(0xFFF1F0ED),
    border: Color(0xFFE7E5E4),
    text: Color(0xFF292524),
    textSecondary: Color(0xFF78716C),
    textMuted: Color(0xFFA8A29E),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
  );

  static const dark = AppColors(
    canvas: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    sidebar: Color(0xFF010409),
    secondarySurface: Color(0xFF21262D),
    border: Color(0xFF30363D),
    text: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B949E),
    textMuted: Color(0xFF6E7681),
    success: Color(0xFF3FB950),
    warning: Color(0xFFD29922),
    danger: Color(0xFFF85149),
  );

  @override
  AppColors copyWith({
    Color? canvas, Color? surface, Color? sidebar, Color? secondarySurface, Color? border,
    Color? text, Color? textSecondary, Color? textMuted, Color? success, Color? warning, Color? danger,
  }) =>
      AppColors(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        sidebar: sidebar ?? this.sidebar,
        secondarySurface: secondarySurface ?? this.secondarySurface,
        border: border ?? this.border,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 || other is! AppColors ? this : other;
}
