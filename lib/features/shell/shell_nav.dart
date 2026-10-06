import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_state.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

IconData menuIconFor(String icon) => switch (icon) {
      'schedule' => Icons.schedule_outlined,
      'calendar_month' => Icons.calendar_month_outlined,
      'assignment' => Icons.assignment_outlined,
      'assignment_ind' => Icons.assignment_ind_outlined,
      'payments' => Icons.payments_outlined,
      'card_giftcard' => Icons.card_giftcard_outlined,
      'people' => Icons.people_outline,
      'access_time' => Icons.access_time_outlined,
      'event_repeat' => Icons.event_repeat_outlined,
      'grid_on' => Icons.grid_on_outlined,
      'fact_check' => Icons.fact_check_outlined,
      'remove_circle_outline' => Icons.remove_circle_outline,
      'account_balance_wallet' => Icons.account_balance_wallet_outlined,
      'assessment' => Icons.assessment_outlined,
      'settings' => Icons.settings_outlined,
      'account_tree' => Icons.account_tree_outlined,
      'request_quote' => Icons.request_quote_outlined,
      'my_location' => Icons.my_location_outlined,
      _ => Icons.dashboard_outlined,
    };

/// Same menu pipeline for web and mobile — role + entitlements come from `/me`.
List<NavItem> navItemsFromMenus(BuildContext context, List<BioTimeMenuItem> menus) {
  final l10n = AppLocalizations.of(context);

  if (menus.isEmpty) {
    return [NavItem(l10n.home, Icons.dashboard_outlined, AppRoutes.dashboard)];
  }

  final filtered = menus
      .where((m) =>
          m.id != 'shift_assignments' &&
          !m.route.startsWith('/hr/shift-assignments') &&
          m.id != 'overtime' &&
          !m.route.startsWith('/hr/overtime') &&
          // Super Admin shell is web-only; never surface /admin in the mobile drawer.
          !m.route.startsWith('/admin'))
      .map((m) => NavItem(l10n.menuLabel(m.id), menuIconFor(m.icon), m.route))
      .toList();

  if (filtered.isEmpty) {
    return [NavItem(l10n.home, Icons.dashboard_outlined, AppRoutes.dashboard)];
  }
  return filtered;
}

/// Bottom-bar destinations beside Home on native mobile, picked by role from
/// the menus the user actually has. Everything else lives in the drawer.
List<NavItem> mobileTabsFor(
  AuthState auth,
  List<NavItem> navItems, {
  int count = 2,
}) {
  final priority = auth.roles.isHrStaff
      ? const [
          AppRoutes.hrEmployees,
          AppRoutes.hrAttendance,
          AppRoutes.requests,
          AppRoutes.hrPayroll,
        ]
      : auth.roles.isBranchManager
          ? const [
              AppRoutes.hrAttendance,
              AppRoutes.hrHiringAppointments,
              AppRoutes.hrShiftGrid,
              AppRoutes.hrShifts,
            ]
          : const [
              AppRoutes.myAttendance,
              AppRoutes.mySchedule,
              AppRoutes.requests,
              AppRoutes.myPayroll,
              AppRoutes.myAdvanceRequest,
            ];
  final tabs = <NavItem>[];
  for (final route in priority) {
    final match = navItems.where((n) => n.route == route);
    if (match.isNotEmpty) tabs.add(match.first);
    if (tabs.length == count) break;
  }
  return tabs;
}
