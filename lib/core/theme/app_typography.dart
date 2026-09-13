import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// Single source of truth for bundled Cairo font (assets/fonts).
abstract final class AppTypography {
  static const String family = AppTheme.fontFamily;

  static TextStyle cairo({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    FontStyle? fontStyle,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: fontFeatures,
        decoration: decoration,
        fontStyle: fontStyle,
      );

  static TextTheme textTheme() {
    // Material 3 themes can include styles with null fontSize; TextTheme.apply
    // asserts when fontSizeFactor != 1.0, so scale sizes manually.
    final base = ThemeData.light(useMaterial3: true).textTheme.apply(
          fontFamily: family,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );
    TextStyle? scale(TextStyle? style) {
      if (style == null || style.fontSize == null) return style;
      return style.copyWith(fontSize: style.fontSize! * kTextScaleFactor);
    }

    return TextTheme(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }

  static TextStyle get body => cairo(
        fontSize: 14 * kTextScaleFactor,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );
}

/// Quick weights for inline styles.
extension AppText on TextStyle {
  static TextStyle get w400 => AppTypography.cairo(fontWeight: FontWeight.w400);
  static TextStyle get w500 => AppTypography.cairo(fontWeight: FontWeight.w500);
  static TextStyle get w600 => AppTypography.cairo(fontWeight: FontWeight.w600);
  static TextStyle get w700 => AppTypography.cairo(fontWeight: FontWeight.w700);
  static TextStyle get w800 => AppTypography.cairo(fontWeight: FontWeight.w800);
}
