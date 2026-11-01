import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// App logo: gradient tile with an icon, followed by the app name.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.onGradient = false, this.size = 44});

  /// Set to true when the logo is drawn on top of a gradient background.
  final bool onGradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textColor =
        onGradient ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: onGradient ? null : AppColors.brandGradient,
            color: onGradient ? Colors.white.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.fact_check_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
        SizedBox(width: size * 0.28),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: textColor,
          ),
        ),
      ],
    );
  }
}