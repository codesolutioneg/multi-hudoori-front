import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Global text scale — bump all UI text sizes.
const double kTextScaleFactor = 1.18;

abstract final class AppTheme {
  static const String fontFamily = 'Cairo';

  /// Native Android/iOS: denser, rounder controls on a soft blue-grey canvas.
  static ThemeData mobile() {
    final base = light();
    final cairo = AppTypography.cairo;
    const primary = Color(0xFF2F6BFF);
    const line = Color(0xFFE6EBF3);
    const canvas = Color(0xFFF4F7FC);
    final r14 = BorderRadius.circular(14);
    final pill = RoundedRectangleBorder(borderRadius: r14);
    final label = cairo(fontWeight: FontWeight.w700, fontSize: 14);

    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: base.colorScheme.copyWith(primary: primary),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: r14, borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: r14, borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
          borderRadius: r14,
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        labelStyle: cairo(color: AppColors.textSecondary, fontSize: 14),
        floatingLabelStyle: cairo(color: primary, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: label,
          shape: pill,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: label,
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: line),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: label,
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: label,
          shape: pill,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFE8F0FF),
        checkmarkColor: primary,
        showCheckmark: false,
        side: const BorderSide(color: line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelStyle: cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        secondaryLabelStyle: cairo(fontSize: 13, fontWeight: FontWeight.w700, color: primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEDF1F7)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEFF2F7), thickness: 1),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: r14),
      ),
    );
  }

  static ThemeData light() {
    final cairoTheme = AppTypography.textTheme();
    final cairo = AppTypography.cairo;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.muted,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: cairoTheme,
      primaryTextTheme: cairoTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: cairoTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        toolbarTextStyle: cairoTheme.bodyMedium,
      ),
      dividerTheme: DividerThemeData(color: AppColors.border.withValues(alpha: 0.8), thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: cairo(color: AppColors.textMuted),
        labelStyle: cairo(),
        helperStyle: cairo(fontSize: 12, color: AppColors.textSecondary),
        errorStyle: cairo(fontSize: 12, color: AppColors.danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: cairo(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: cairo(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          textStyle: cairo(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: cairo(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: cairo(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        subtitleTextStyle: cairo(fontSize: 13, color: AppColors.textSecondary),
        leadingAndTrailingTextStyle: cairo(fontSize: 13, color: AppColors.textPrimary),
      ),
      // Text styles without a color render white on iOS/Android (black on web).
      chipTheme: ChipThemeData(
        labelStyle: cairo(fontSize: 13 * kTextScaleFactor, color: AppColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary);
          }
          return cairo(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedLabelTextStyle: cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
        unselectedLabelTextStyle: cairo(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: cairo(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        contentTextStyle: cairo(fontSize: 14, color: AppColors.textSecondary, height: 1.45),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: cairo(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: cairo(fontSize: 12, color: Colors.white),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: cairo(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: cairo(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: cairo(fontSize: 14, color: AppColors.textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: cairo(fontSize: 14, color: AppColors.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radius2xl)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}
