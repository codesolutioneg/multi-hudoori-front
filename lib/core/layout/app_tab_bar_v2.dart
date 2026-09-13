import 'package:flutter/material.dart';

import '../theme/app_theme_v2.dart';

/// Dashboard v2 styled tab bar for detail screens.
class AppTabBarV2 extends StatelessWidget {
  const AppTabBarV2({super.key, required this.controller, required this.tabs});

  final TabController controller;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeV2.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV2.border),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: AppThemeV2.primaryGradient,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppThemeV2.textSecondary,
        labelStyle: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: AppThemeV2.caption.copyWith(fontSize: 13),
        tabs: tabs,
      ),
    );
  }
}
