import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Global text scale — bump all UI text sizes.
const double kTextScaleFactor = 1.18;

abstract final class AppTheme {
  static const String fontFamily = 'Cairo';

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
        titleTextStyle: cairo(fontWeight: FontWeight.w600),
        subtitleTextStyle: cairo(fontSize: 13, color: AppColors.textSecondary),
        leadingAndTrailingTextStyle: cairo(fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        labelStyle: cairo(fontSize: 13 * kTextScaleFactor),
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
        textStyle: cairo(fontSize: 14),
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
