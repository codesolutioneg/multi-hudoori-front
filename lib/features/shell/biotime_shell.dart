import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/hudoori_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../features/dashboard/widgets/dashboard_page_background.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'dashboard_notifications_panel.dart';
import 'shell_nav.dart';
import '../assistant/help_assistant_overlay.dart';

class BioTimeShell extends StatefulWidget {
  const BioTimeShell({super.key, required this.child});
  final Widget child;

  @override
  State<BioTimeShell> createState() => _BioTimeShellState();
}

class _BioTimeShellState extends State<BioTimeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final location = GoRouterState.of(context).matchedLocation;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final l10n = AppLocalizations.of(context);
        final navItems = navItemsFromMenus(context, auth.menus);
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
                  child: _Sidebar(
                    location: location,
                    navItems: navItems,
                    onTap: _closeDrawer,
                  ),
                )
              : null,
          bottomNavigationBar: mobile
              ? _BottomNav(location: location, navItems: navItems)
              : null,
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
                      userRole: l10n.roleLabel(
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
            if (auth.canViewAssistant) const HelpAssistantOverlay(),
          ],
        );
      },
    );
  }

  void _closeDrawer() => Navigator.of(context).pop();
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
                      context.go(item.route);
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
  });
  final VoidCallback? onMenu;
  final String userName;
  final String userRole;
  final bool showNotifications;

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

  @override
  Widget build(BuildContext context) {
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

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location, required this.navItems});
  final String location;
  final List<NavItem> navItems;

  @override
  Widget build(BuildContext context) {
    final items = navItems.take(4).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    var index = 0;
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) index = i;
    }
    return NavigationBar(
      backgroundColor: AppThemeV2.surface,
      indicatorColor: AppThemeV2.primarySoft,
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(items[i].route),
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}
