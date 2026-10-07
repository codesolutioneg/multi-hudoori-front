import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/locale/locale_cubit.dart';
import '../../core/platform/mobile_platform.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/feature_entitlements.dart';
import '../../core/widgets/hudoori_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../features/dashboard/widgets/dashboard_page_background.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../auth/biometric_login.dart';
import '../auth/company_membership_picker.dart';
import '../mobile/mobile_bottom_bar.dart';
import '../mobile/mobile_more_page.dart';
import '../mobile/mobile_top_header.dart';
import 'hr_company_switcher.dart';
import '../mobile/mobile_ui.dart';
import '../mobile/my_photo.dart';
import 'dashboard_notifications_panel.dart';
import 'shell_nav.dart';

class BioTimeShell extends StatefulWidget {
  const BioTimeShell({super.key, required this.child});
  final Widget child;

  @override
  State<BioTimeShell> createState() => _BioTimeShellState();
}

class _BioTimeShellState extends State<BioTimeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _moreOpen = false;
  String? _lastLocation;
  bool _pickerOpen = false;

  Future<void> _maybeShowCompanyPicker(AuthState auth) async {
    if (!auth.pendingCompanyPicker || !auth.canSwitchCompany || _pickerOpen) return;
    _pickerOpen = true;
    await showCompanyMembershipPicker(
      context,
      memberships: auth.memberships,
      activeCompanyId: auth.activeCompanyId,
    );
    if (mounted) {
      context.read<AuthCubit>().clearPendingCompanyPicker();
      _pickerOpen = false;
    }
  }

  @override
  void dispose() {
    if (isNativeMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mobileStatusBarColor.value == MobileTopHeader.top) {
          mobileStatusBarColor.value = MobileUi.background;
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final location = GoRouterState.of(context).matchedLocation;

    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (a, b) =>
          a.pendingCompanyPicker != b.pendingCompanyPicker ||
          a.memberships.length != b.memberships.length,
      listener: (context, auth) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShowCompanyPicker(auth);
        });
      },
      builder: (context, auth) {
        final l10n = AppLocalizations.of(context);
        final navItems = navItemsFromMenus(context, auth.menus);
        if (mobile && isNativeMobile) {
          return _buildNativeMobile(context, auth, navItems, location);
        }
        assert(() {
          debugPrint(
            '[BioTimeShell] mobile=${isMobile(context)} '
            'menus=${auth.menus.length} navItems=${navItems.length} '
            'routes=${navItems.map((e) => e.route).join(",")}',
          );
          return true;
        }());
        return Stack(
          children: [
            Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppThemeV2.background,
          drawer: mobile
              ? Drawer(
                  width: MediaQuery.sizeOf(context).width * 0.86,
                  child: _Sidebar(
                    location: location,
                    navItems: navItems,
                    onTap: _closeDrawer,
                  ),
                )
              : null,
          // Mobile uses the same drawer menu as the web sidebar — no bottom bar.
          body: Row(
            children: [
              if (!mobile)
                _Sidebar(
                  location: location,
                  navItems: navItems,
                  collapsed: isTablet(context),
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      onMenu: mobile
                          ? () => _scaffoldKey.currentState?.openDrawer()
                          : null,
                      userName: auth.user?.name ?? auth.employeeName,
                      userRole: auth.isPlatformAdmin
                          ? l10n.t('role.platformAdmin')
                          : l10n.roleLabel(
                              isSystemAdmin: auth.roles.isSystemAdmin,
                              isHrManager: auth.roles.isHrManager,
                              isHrSupervisor: auth.roles.isHrSupervisor,
                              isBranchManager: auth.roles.isBranchManager,
                              isEmployee: auth.roles.isEmployee,
                            ),
                      showNotifications:
                          auth.roles.isHrStaff || auth.roles.isBranchManager,
                    ),
                    Expanded(
                      child: DashboardPageBackground(child: widget.child),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
            // Help assistant FAB hidden per product request (2026-09-15).
          ],
        );
      },
    );
  }

  void _closeDrawer() => Navigator.of(context).pop();

  Widget _buildNativeMobile(
    BuildContext context,
    AuthState auth,
    List<NavItem> navItems,
    String location,
  ) {
    final l10n = AppLocalizations.of(context);
    final staff = auth.roles.isHrStaff || auth.roles.isBranchManager;
    final homeRoute = staff ? AppRoutes.hrDashboard : AppRoutes.dashboard;
    final hasPunch = (navItems.any((n) => n.route == AppRoutes.myLocationPunch) ||
            auth.features.mobileLocationPunch) &&
        isRouteEntitled(auth, AppRoutes.myLocationPunch);
    final picked = mobileTabsFor(auth, navItems, count: hasPunch ? 2 : 3);
    final NavItem? centerItem = hasPunch
        ? null
        : (picked.isNotEmpty ? picked.first : null);
    final tabs = hasPunch ? picked : picked.skip(1).toList();
    final centerRoute = hasPunch ? AppRoutes.myLocationPunch : centerItem?.route;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    void go(String route) {
      if (!isRouteEntitled(auth, route)) {
        final feat = featureKeyForRoute(route);
        context.go(feat != null
            ? AppRoutes.accessDeniedFeature(feat)
            : AppRoutes.accessDeniedRole());
        return;
      }
      context.go(route);
    }

    if (location != _lastLocation) {
      _lastLocation = location;
      _moreOpen = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mobileStatusBarColor.value = MobileTopHeader.top;
      MyPhoto.load(auth.employeeId);
      BiometricLogin.offerIfPending(context);
    });

    void open(String route) {
      if (_moreOpen) setState(() => _moreOpen = false);
      go(route);
    }

    final more = _moreOpen;
    final onHome = !more &&
        (location == homeRoute ||
            location == AppRoutes.dashboard ||
            location == AppRoutes.hrDashboard);
    final onCenter =
        !more && centerRoute != null && location.startsWith(centerRoute);
    final tabIndex =
        more ? -1 : tabs.indexWhere((t) => location.startsWith(t.route));

    final items = <MobileNavEntry>[
      MobileNavEntry(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: l10n.home,
        selected: onHome,
        onTap: () => open(homeRoute),
      ),
      for (var i = 0; i < tabs.length; i++)
        MobileNavEntry(
          icon: tabs[i].icon,
          activeIcon: _filledIcon(tabs[i].icon),
          label: tabs[i].label,
          selected: tabIndex == i,
          onTap: () => open(tabs[i].route),
        ),
      MobileNavEntry(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: l10n.t('m.more'),
        selected: more || (!onHome && !onCenter && tabIndex < 0),
        onTap: () => setState(() => _moreOpen = !_moreOpen),
      ),
    ];

    final role = auth.isPlatformAdmin
        ? l10n.t('role.platformAdmin')
        : l10n.roleLabel(
            isSystemAdmin: auth.roles.isSystemAdmin,
            isHrManager: auth.roles.isHrManager,
            isHrSupervisor: auth.roles.isHrSupervisor,
            isBranchManager: auth.roles.isBranchManager,
            isEmployee: auth.roles.isEmployee,
          );

    return PopScope(
      canPop: !more,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _moreOpen = false);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: MobileUi.background,
        body: Column(
          children: [
            _TopBar(
              nativeMobile: true,
              flat: !more &&
                  (location == AppRoutes.dashboard ||
                      location == AppRoutes.hrDashboard),
              userName: auth.employeeName.isNotEmpty
                  ? auth.employeeName
                  : (auth.user?.name ?? ''),
              userRole: role,
              company: auth.activeCompanyName,
              showNotifications:
                  auth.roles.isHrStaff || auth.roles.isBranchManager,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: widget.child),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !more,
                      child: AnimatedOpacity(
                        opacity: more ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: more
                            ? MobileMorePage(
                                items: navItems,
                                location: location,
                                onOpen: open,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: centerRoute == null || keyboardOpen
            ? null
            : MobileCenterButton(
                selected: onCenter,
                icon: hasPunch ? null : _filledIcon(centerItem!.icon),
                tooltip: hasPunch ? l10n.t('m.punch') : centerItem!.label,
                onTap: () => open(centerRoute),
              ),
        bottomNavigationBar:
            keyboardOpen ? null : MobileBottomBar(items: items),
      ),
    );
  }

  static IconData _filledIcon(IconData outlined) => switch (outlined) {
        Icons.schedule_outlined => Icons.schedule_rounded,
        Icons.calendar_month_outlined => Icons.calendar_month_rounded,
        Icons.assignment_outlined => Icons.assignment_rounded,
        Icons.assignment_ind_outlined => Icons.assignment_ind_rounded,
        Icons.payments_outlined => Icons.payments_rounded,
        Icons.people_outline => Icons.people_alt_rounded,
        Icons.access_time_outlined => Icons.access_time_filled_rounded,
        Icons.grid_on_outlined => Icons.grid_on_rounded,
        Icons.fact_check_outlined => Icons.fact_check_rounded,
        Icons.request_quote_outlined => Icons.request_quote_rounded,
        Icons.account_balance_wallet_outlined =>
          Icons.account_balance_wallet_rounded,
        _ => outlined,
      };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.location,
    required this.navItems,
    this.collapsed = false,
    this.onTap,
  });
  final String location;
  final List<NavItem> navItems;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const widthExpanded = 260.0;
    const widthCollapsed = 72.0;
    final width = collapsed ? widthCollapsed : widthExpanded;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppThemeV2.surface,
        border: Border(
          left: BorderSide(color: AppThemeV2.border.withValues(alpha: 0.9)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeV2.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 12 : 20,
              20,
              collapsed ? 12 : 20,
              12,
            ),
            child: Column(
              crossAxisAlignment: collapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                HudooriLogo(
                  iconSize: collapsed ? 32 : 36,
                  nameSize: 22,
                  showName: !collapsed,
                  showBackground: false,
                ),
                if (!collapsed &&
                    (context.watch<AuthCubit>().state.activeCompanyName ?? '')
                        .isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.watch<AuthCubit>().state.activeCompanyName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppThemeV2.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppThemeV2.primary,
                    ),
                  ),
                  if ((context.watch<AuthCubit>().state.activeCompanyCode ?? '')
                      .isNotEmpty)
                    Text(
                      context.watch<AuthCubit>().state.activeCompanyCode!,
                      style: AppThemeV2.caption.copyWith(fontSize: 11),
                    ),
                ],
              ],
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(height: 1, color: AppThemeV2.border),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: [
                for (final item in navItems)
                  _SidebarTile(
                    item: item,
                    selected: location.startsWith(item.route),
                    collapsed: collapsed,
                    onTap: () {
                      final auth = context.read<AuthCubit>().state;
                      if (!isRouteEntitled(auth, item.route)) {
                        final feat = featureKeyForRoute(item.route);
                        context.go(
                          feat != null
                              ? AppRoutes.accessDeniedFeature(feat)
                              : AppRoutes.accessDeniedRole(),
                        );
                      } else {
                        context.go(item.route);
                      }
                      onTap?.call();
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Tooltip(
              message: collapsed ? AppLocalizations.of(context).logout : '',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await context.read<AuthCubit>().signOut();
                    if (context.mounted) context.go(AppRoutes.signIn);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 10 : 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: collapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: AppThemeV2.textMuted,
                        ),
                        if (!collapsed) ...[
                          const SizedBox(width: 10),
                          Text(
                            AppLocalizations.of(context).logout,
                            style: AppThemeV2.cardSubtitle.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });
  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final fg = selected ? AppThemeV2.primary : AppThemeV2.textSecondary;
    final bg = selected
        ? AppThemeV2.primarySoft
        : (_hovered ? AppThemeV2.surfaceElevated : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.collapsed ? 14 : 12,
                vertical: 11,
              ),
              child: Row(
                children: [
                  Icon(widget.item.icon, size: 20, color: fg),
                  if (!widget.collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: AppThemeV2.sidebarNavLabel(selected: selected),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    this.onMenu,
    required this.userName,
    required this.userRole,
    this.showNotifications = false,
    this.nativeMobile = false,
    this.flat = false,
    this.company,
  });
  final VoidCallback? onMenu;
  final bool flat;
  final String userName;
  final String userRole;
  final String? company;
  final bool showNotifications;
  final bool nativeMobile;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  int _notifCount = 0;
  List<DashboardNotificationSection> _sections = [];
  bool _loadingNotif = false;

  @override
  void initState() {
    super.initState();
    if (widget.showNotifications) _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant _TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showNotifications && !oldWidget.showNotifications) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (!widget.showNotifications || _loadingNotif) return;
    setState(() => _loadingNotif = true);
    try {
      final data = await api.dashboardNotifications();
      if (!mounted) return;
      final sections = ((data['sections'] as List?) ?? [])
          .whereType<Map>()
          .map(
            (e) => DashboardNotificationSection.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
      setState(() {
        _sections = sections;
        _notifCount = (data['totalCount'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // ignore — bell stays without badge
    } finally {
      if (mounted) setState(() => _loadingNotif = false);
    }
  }

  Future<void> _openNotifications() async {
    await _loadNotifications();
    if (!mounted) return;
    await showDashboardNotificationsPanel(
      context,
      sections: _sections,
      totalCount: _notifCount,
      onReadAll: () async {
        await api.dashboardNotificationsReadAll();
        if (!mounted) return;
        setState(() {
          _sections = const [];
          _notifCount = 0;
        });
      },
    );
    if (mounted) _loadNotifications();
  }

  Widget _buildNativeMobile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>().state;
    return MobileTopHeader(
      flat: widget.flat,
      name: widget.userName,
      role: widget.userRole,
      company: widget.company,
      onCompanyTap: auth.canSwitchCompany
          ? () => showCompanyMembershipPicker(
                context,
                memberships: auth.memberships,
                activeCompanyId: auth.activeCompanyId,
              )
          : null,
      actions: [
        MobileHeaderButton(
          tooltip: l10n.language,
          onPressed: () {
            final cubit = context.read<LocaleCubit>();
            cubit.setLocale(Locale(l10n.isAr ? 'en' : 'ar'));
          },
          child: Text(
            l10n.isAr ? 'EN' : 'ع',
            style: MobileUi.text(14, weight: FontWeight.w800, color: Colors.white, height: 1),
          ),
        ),
        if (widget.showNotifications)
          MobileHeaderButton(
            tooltip: l10n.t('notif.title'),
            onPressed: _openNotifications,
            child: Badge(
              isLabelVisible: _notifCount > 0,
              backgroundColor: const Color(0xFFFF4D4F),
              label: Text(_notifCount > 99 ? '99+' : '$_notifCount'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nativeMobile) return _buildNativeMobile(context);
    final mobile = widget.onMenu != null;
    final narrow = MediaQuery.sizeOf(context).width < 480;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeV2.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: AppThemeV2.border.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          if (widget.onMenu != null)
            IconButton(
              onPressed: widget.onMenu,
              icon: const Icon(Icons.menu_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppThemeV2.surfaceElevated,
              ),
            ),
          if (mobile) const HrCompanySwitcher(),
          const Spacer(),
          if (!mobile) const LanguageToggle(),
          if (widget.showNotifications) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: AppLocalizations.of(context).t('notif.title'),
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: _notifCount > 0,
                label: Text(_notifCount > 99 ? '99+' : '$_notifCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppThemeV2.surfaceElevated,
                foregroundColor: AppThemeV2.textPrimary,
              ),
            ),
          ],
          if (!mobile) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppThemeV2.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppThemeV2.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppThemeV2.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  if (!narrow) ...[
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.userName,
                          style: AppThemeV2.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          widget.userRole,
                          style: AppThemeV2.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
