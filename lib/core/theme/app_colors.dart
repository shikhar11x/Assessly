import 'package:flutter/material.dart';

/// Central color palette for the whole app.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color violet = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF22D3EE);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Backgrounds
  static const Color lightBackground = Color(0xFFF5F6FB);
  static const Color darkBackground = Color(0xFF0B0F1A);
  static const Color darkSurface = Color(0xFF131929);

  // Borders
  static const Color lightOutline = Color(0xFFE2E5EF);
  static const Color darkOutline = Color(0xFF2A3145);

  /// Used for buttons and logo tiles.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, violet],
  );

  /// Used for the splash screen and the login brand panel.
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );
}