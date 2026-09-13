import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Default employee self-service destinations for native iOS/Android.
List<NavItem> defaultMobileEmployeeNav(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    NavItem(l10n.menuLabel('dashboard'), Icons.dashboard_outlined, AppRoutes.dashboard),
    NavItem(l10n.menuLabel('my_schedule'), Icons.calendar_month_outlined, AppRoutes.mySchedule),
    NavItem(l10n.menuLabel('my_attendance'), Icons.schedule_outlined, AppRoutes.myAttendance),
    NavItem(
      l10n.menuLabel('my_advance_request'),
      Icons.request_quote_outlined,
      AppRoutes.myAdvanceRequest,
    ),
  ];
}

bool _isMobileSelfServiceRoute(String route) =>
    !route.startsWith('/hr') && !route.startsWith('/admin');

List<NavItem> navItemsFromMenus(BuildContext context, List<BioTimeMenuItem> menus) {
  final l10n = AppLocalizations.of(context);

  if (menus.isEmpty) {
    // Web keeps a single Home fallback; mobile always gets the full
    // employee self-service set so bottom nav / drawer are usable.
    return kIsWeb
        ? [NavItem(l10n.home, Icons.dashboard_outlined, AppRoutes.dashboard)]
        : defaultMobileEmployeeNav(context);
  }

  final filtered = menus
      .where((m) =>
          m.id != 'shift_assignments' &&
          !m.route.startsWith('/hr/shift-assignments') &&
          m.id != 'overtime' &&
          !m.route.startsWith('/hr/overtime') &&
          // Mobile is employee self-service only: hide HR + admin menus.
          // Web dashboard keeps the full set.
          (kIsWeb || _isMobileSelfServiceRoute(m.route)))
      .map((m) => NavItem(l10n.menuLabel(m.id), menuIconFor(m.icon), m.route))
      .toList();

  if (!kIsWeb && filtered.isEmpty) {
    // HR/admin accounts often only receive /hr menus — after filtering
    // nothing would remain and bottom nav / drawer would disappear.
    return defaultMobileEmployeeNav(context);
  }

  if (filtered.isEmpty) {
    return [NavItem(l10n.home, Icons.dashboard_outlined, AppRoutes.dashboard)];
  }
  return filtered;
}
