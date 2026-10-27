import 'package:flutter/material.dart';

/// Editorial type scale for STYL.
///
/// Uses the platform default sans until Figma typefaces are bundled
/// under `assets/fonts/` and registered in `pubspec.yaml`.
abstract final class AppTextStyles {
  static const String fontFamily = 'Roboto';

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: _style(
        size: 40,
        height: 48,
        weight: FontWeight.w600,
        letterSpacing: -0.8,
        color: primary,
      ),
      displayMedium: _style(
        size: 34,
        height: 42,
        weight: FontWeight.w600,
        letterSpacing: -0.6,
        color: primary,
      ),
      displaySmall: _style(
        size: 28,
        height: 36,
        weight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineLarge: _style(
        size: 26,
        height: 34,
        weight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineMedium: _style(
        size: 22,
        height: 30,
        weight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      headlineSmall: _style(
        size: 20,
        height: 28,
        weight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: _style(
        size: 18,
        height: 26,
        weight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: _style(
        size: 16,
        height: 24,
        weight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primary,
      ),
      titleSmall: _style(
        size: 14,
        height: 20,
        weight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primary,
      ),
      bodyLarge: _style(
        size: 16,
        height: 24,
        weight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: _style(
        size: 14,
        height: 22,
        weight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: _style(
        size: 12,
        height: 18,
        weight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: _style(
        size: 14,
        height: 20,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primary,
      ),
      labelMedium: _style(
        size: 12,
        height: 16,
        weight: FontWeight.w600,
        letterSpacing: 0.3,
        color: primary,
      ),
      labelSmall: _style(
        size: 11,
        height: 14,
        weight: FontWeight.w600,
        letterSpacing: 0.4,
        color: secondary,
      ),
    );
  }

  static TextStyle _style({
    required double size,
    required double height,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
