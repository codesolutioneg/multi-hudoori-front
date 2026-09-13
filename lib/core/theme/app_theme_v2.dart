import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_typography.dart';

class AppThemeV2 {
  // Light SaaS Palette — Clean, airy, professional
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);

  static const Color primary = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFDBEAFE);
  static const Color primaryGlow = Color(0xFF3B82F6);

  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0891B2);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 8,
          offset: Offset(0, 2),
          spreadRadius: -2,
        ),
        const BoxShadow(
          color: Color(0x0F0F172A),
          blurRadius: 16,
          offset: Offset(0, 4),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.12),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];

  static const double cardRadius = 16.0;
  static const double cardPadding = 20.0;
  static const double sectionGap = 24.0;

  /// Ensures Cairo is loaded the same way as settings cards (Google Fonts package).
  static TextStyle _cairo({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) =>
      AppTypography.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: fontFeatures,
      );

  static TextStyle get headline => _cairo(
        fontSize: 28 * kTextScaleFactor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
        height: 1.2,
      );

  static TextStyle get title => _cairo(
        fontSize: 18 * kTextScaleFactor,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get body => _cairo(
        fontSize: 16 * kTextScaleFactor,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => _cairo(
        fontSize: 14 * kTextScaleFactor,
        fontWeight: FontWeight.w500,
        color: textMuted,
        height: 1.4,
      );

  /// Settings accordion card title — reference typography for the app.
  static TextStyle cardTitle({Color? color}) => _cairo(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color ?? textPrimary,
        height: 1.35,
      );

  /// Settings accordion card subtitle.
  static TextStyle get cardSubtitle => _cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.35,
      );

  /// Sidebar nav — same Cairo loading as settings cards.
  static TextStyle sidebarNavLabel({required bool selected}) => _cairo(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: selected ? primary : textPrimary,
        height: 1.35,
      );

  static TextStyle get statValue => _cairo(
        fontSize: 36 * kTextScaleFactor,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.0,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
