import 'package:flutter/material.dart';

import '../platform/mobile_platform.dart';
import '../theme/app_theme_v2.dart';

/// Dashboard v2 styled tab bar for detail screens.
class AppTabBarV2 extends StatelessWidget {
  const AppTabBarV2({super.key, required this.controller, required this.tabs});

  final TabController controller;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    if (isNativeMobile) {
      return Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDF1F7)),
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(12),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF4C8DFF), Color(0xFF2563EB)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x332F6BFF), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5),
          unselectedLabelStyle: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
          tabs: tabs,
        ),
      );
    }
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
