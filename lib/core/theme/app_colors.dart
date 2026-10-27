import 'package:flutter/material.dart';

/// STYL brand and semantic colors from Figma (STYL App Design).
abstract final class AppColors {
  /// Figma `fill_523a343f` — primary navy.
  static const Color brandPrimary = Color(0xFF003E6F);

  /// Figma `fill_75ded6f3` — selection accent orange.
  static const Color brandAccent = Color(0xFFF1592A);

  static const Color brandSecondary = Color(0xFF31373A);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightCanvas = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF2F3F7);
  static const Color lightOnBackground = Color(0xFF000000);
  static const Color lightOnSurface = Color(0xFF000000);
  static const Color lightOnSurfaceVariant = Color(0xFF4A5568);
  static const Color lightMuted = Color(0xFFDFDFDF);
  static const Color lightOutline = Color(0xFFD9D9D9);
  static const Color lightOutlineVariant = Color(0xFFE8E8E8);
  /// Secondary labels / captions — darker than before for readability.
  static const Color lightHint = Color(0xFF4A5568);

  static const Color darkBackground = Color(0xFF0A1620);
  static const Color darkSurface = Color(0xFF122232);
  static const Color darkSurfaceVariant = Color(0xFF1B2E40);
  static const Color darkOnBackground = Color(0xFFF4F6FA);
  static const Color darkOnSurface = Color(0xFFF2F3F7);
  static const Color darkOnSurfaceVariant = Color(0xFFA8B3BE);
  static const Color darkOutline = Color(0xFF2E4254);
  static const Color darkOutlineVariant = Color(0xFF243748);

  static const Color success = Color(0xFF2F9E6B);
  static const Color warning = Color(0xFFE0A106);
  static const Color error = Color(0xFFD64545);
  static const Color info = Color(0xFF1E8CF2);
}

/// Brand colors that sit outside [ColorScheme].
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.accent,
    required this.success,
    required this.warning,
    required this.info,
    required this.canvas,
    required this.muted,
  });

  final Color accent;
  final Color success;
  final Color warning;
  final Color info;
  final Color canvas;
  final Color muted;

  static const AppThemeColors light = AppThemeColors(
    accent: AppColors.brandAccent,
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    canvas: AppColors.lightCanvas,
    muted: AppColors.lightMuted,
  );

  static const AppThemeColors dark = AppThemeColors(
    accent: AppColors.brandAccent,
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    canvas: AppColors.darkBackground,
    muted: AppColors.darkOnSurfaceVariant,
  );

  @override
  AppThemeColors copyWith({
    Color? accent,
    Color? success,
    Color? warning,
    Color? info,
    Color? canvas,
    Color? muted,
  }) {
    return AppThemeColors(
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      canvas: canvas ?? this.canvas,
      muted: muted ?? this.muted,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// Shortcuts for theme tokens on [BuildContext].
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => theme.colorScheme;

  TextTheme get textStyles => theme.textTheme;

  AppThemeColors get appColors => theme.extension<AppThemeColors>()!;

  bool get isDark => theme.brightness == Brightness.dark;
}
