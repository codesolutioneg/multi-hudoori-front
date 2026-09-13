import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/hudoori_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../features/dashboard/widgets/dashboard_page_background.dart';
import '../../l10n/l10n_extension.dart';
import '../assistant/help_assistant_overlay.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';

class AdminNavItem {
  const AdminNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final String route;
}

const _adminNavItemDefs = [
  (id: 'dashboard', key: 'admin.shell.dashboard', icon: Icons.admin_panel_settings_outlined, route: AppRoutes.adminDashboard),
  (id: 'companies', key: 'admin.companies', icon: Icons.apartment_outlined, route: AppRoutes.adminCompanies),
  (id: 'users', key: 'admin.users', icon: Icons.people_outline_rounded, route: AppRoutes.adminUsers),
  (id: 'create', key: 'admin.createUser', icon: Icons.person_add_alt_1_outlined, route: AppRoutes.adminCreateUser),
  (id: 'audit_access', key: 'admin.auditAccess', icon: Icons.history_edu_outlined, route: AppRoutes.adminAuditAccess),
  (id: 'assistant_access', key: 'admin.assistantAccess', icon: Icons.forum_outlined, route: AppRoutes.adminAssistantAccess),
  (id: 'employee_delete_access', key: 'admin.employeeDeleteAccess', icon: Icons.delete_forever_outlined, route: AppRoutes.adminEmployeeDeleteAccess),
  (id: 'audit_log', key: 'admin.auditLog', icon: Icons.manage_search_outlined, route: AppRoutes.hrAudit),
  (id: 'org_chart', key: 'admin.orgChart', icon: Icons.account_tree_outlined, route: AppRoutes.orgChart),
];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final location = GoRouterState.of(context).matchedLocation;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        return Stack(
          children: [
            Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppThemeV2.background,
      drawer: mobile
          ? Drawer(child: _AdminSidebar(location: location, onTap: () => Navigator.of(context).pop()))
          : null,
      body: Row(
        children: [
          if (!mobile) _AdminSidebar(location: location, collapsed: isTablet(context)),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  onMenu: mobile ? () => _scaffoldKey.currentState?.openDrawer() : null,
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
}

/// Nav items that need an active company context (users / settings-style screens).
const _companyScopedNavIds = {
  'users',
  'create',
  'audit_access',
  'assistant_access',
  'employee_delete_access',
  'audit_log',
  'org_chart',
};

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.location, this.collapsed = false, this.onTap});
  final String location;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 72.0 : 260.0;
    final auth = context.watch<AuthCubit>().state;
    final hasCompany = auth.hasActiveCompany;
    final isAr = context.l10n.isAr;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppThemeV2.surface,
        border: Border(left: BorderSide(color: AppThemeV2.border.withValues(alpha: 0.9))),
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
            padding: EdgeInsets.fromLTRB(collapsed ? 12 : 20, 20, collapsed ? 12 : 20, 8),
            child: HudooriLogo(
              iconSize: collapsed ? 32 : 36,
              nameSize: 22,
              showName: !collapsed,
              showBackground: false,
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppThemeV2.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppThemeV2.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppThemeV2.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('admin.platformManager'),
                        style: AppThemeV2.caption.copyWith(
                          color: AppThemeV2.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!collapsed && !hasCompany)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                isAr
                    ? 'اختر شركة من الشريط العلوي قبل إدارة المستخدمين والإعدادات.'
                    : 'Select a company in the top bar before managing users and settings.',
                style: AppThemeV2.caption.copyWith(fontSize: 11, color: AppThemeV2.textMuted),
              ),
            ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(height: 1, color: AppThemeV2.border),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: [
                for (final item in _adminNavItemDefs)
                  _AdminSidebarTile(
                    item: AdminNavItem(
                      id: item.id,
                      label: context.t(item.key),
                      icon: item.icon,
                      route: item.route,
                    ),
                    selected: _routeSelected(location, item.route),
                    collapsed: collapsed,
                    enabled: !_companyScopedNavIds.contains(item.id) || hasCompany,
                    onTap: () {
                      if (_companyScopedNavIds.contains(item.id) && !hasCompany) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAr ? 'اختر شركة أولاً' : 'Select a company first',
                            ),
                          ),
                        );
                        context.go(AppRoutes.adminCompanies);
                        onTap?.call();
                        return;
                      }
                      context.go(item.route);
                      onTap?.call();
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  await context.read<AuthCubit>().signOut();
                  if (context.mounted) context.go(AppRoutes.signIn);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: AppThemeV2.textMuted),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Text(
                          context.l10n.logout,
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
        ],
      ),
    );
  }

  bool _routeSelected(String location, String route) {
    if (route == AppRoutes.adminDashboard) return location == route;
    return location.startsWith(route);
  }
}

class _AdminSidebarTile extends StatefulWidget {
  const _AdminSidebarTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.enabled = true,
  });

  final AdminNavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_AdminSidebarTile> createState() => _AdminSidebarTileState();
}

class _AdminSidebarTileState extends State<_AdminSidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final enabled = widget.enabled;
    final fg = !enabled
        ? AppThemeV2.textMuted.withValues(alpha: 0.45)
        : selected
            ? AppThemeV2.primary
            : AppThemeV2.textSecondary;
    final bg = selected
        ? AppThemeV2.primarySoft
        : (_hovered && enabled ? AppThemeV2.surfaceElevated : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(11),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 14 : 12, vertical: 11),
                child: Row(
                  children: [
                    Icon(widget.item.icon, size: 20, color: fg),
                    if (!widget.collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: AppThemeV2.sidebarNavLabel(selected: selected).copyWith(color: fg),
                        ),
                      ),
                      if (!enabled)
                        Icon(Icons.lock_outline, size: 14, color: AppThemeV2.textMuted),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({this.onMenu});
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final mobile = onMenu != null;
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final isAr = context.l10n.isAr;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeV2.surface.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: AppThemeV2.border.withValues(alpha: 0.8))),
      ),
      child: Row(
        children: [
          if (onMenu != null)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
              style: IconButton.styleFrom(backgroundColor: AppThemeV2.surfaceElevated),
            ),
          Flexible(child: _CompanySwitcher(isAr: isAr)),
          const Spacer(),
          if (mobile)
            IconButton(
              tooltip: context.l10n.logout,
              onPressed: () async {
                await context.read<AuthCubit>().signOut();
                if (context.mounted) context.go(AppRoutes.signIn);
              },
              icon: const Icon(Icons.logout_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppThemeV2.surfaceElevated,
                foregroundColor: AppThemeV2.textMuted,
              ),
            ),
          const LanguageToggle(),
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
                  child: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        auth.user?.name ?? context.t('admin.platformManager'),
                        style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        'Platform Admin',
                        style: AppThemeV2.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanySwitcher extends StatefulWidget {
  const _CompanySwitcher({required this.isAr});
  final bool isAr;

  @override
  State<_CompanySwitcher> createState() => _CompanySwitcherState();
}

class _CompanySwitcherState extends State<_CompanySwitcher> {
  List<Map<String, dynamic>> _companies = [];
  bool _loading = false;

  Future<void> _ensureLoaded() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await api.adminCompaniesList();
      final raw = data['companies'];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() { _companies = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final label = auth.hasActiveCompany
        ? '${auth.activeCompanyName ?? ''} (${auth.activeCompanyCode ?? ''})'
        : (widget.isAr ? 'اختر شركة…' : 'Select company…');

    return PopupMenuButton<String>(
      tooltip: widget.isAr ? 'اختيار الشركة' : 'Select company',
      onOpened: _ensureLoaded,
      onSelected: (value) async {
        if (value == '__clear__') {
          await context.read<AuthCubit>().clearActiveCompany();
          return;
        }
        if (value == '__manage__') {
          context.go(AppRoutes.adminCompanies);
          return;
        }
        Map<String, dynamic>? match;
        for (final c in _companies) {
          if (c['id']?.toString() == value) {
            match = c;
            break;
          }
        }
        if (match == null) return;
        await context.read<AuthCubit>().setActiveCompany(
              id: value,
              name: match['name']?.toString(),
              code: match['code']?.toString(),
            );
      },
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<String>>[
          PopupMenuItem(
            value: '__manage__',
            child: Text(widget.isAr ? 'إدارة الشركات…' : 'Manage companies…'),
          ),
          const PopupMenuDivider(),
        ];
        if (_loading && _companies.isEmpty) {
          items.add(PopupMenuItem(
            enabled: false,
            value: '',
            child: Text(widget.isAr ? 'جاري التحميل…' : 'Loading…'),
          ));
        } else if (_companies.isEmpty) {
          items.add(PopupMenuItem(
            enabled: false,
            value: '',
            child: Text(widget.isAr ? 'لا توجد شركات' : 'No companies'),
          ));
        } else {
          for (final c in _companies) {
            final id = c['id']?.toString() ?? '';
            final selected = id == auth.activeCompanyId;
            items.add(PopupMenuItem(
              value: id,
              child: Row(
                children: [
                  if (selected) Icon(Icons.check, size: 16, color: AppThemeV2.primary),
                  if (selected) const SizedBox(width: 8),
                  Expanded(child: Text('${c['name']} (${c['code']})')),
                ],
              ),
            ));
          }
          if (auth.hasActiveCompany) {
            items.add(const PopupMenuDivider());
            items.add(PopupMenuItem(
              value: '__clear__',
              child: Text(widget.isAr ? 'إلغاء الاختيار' : 'Clear selection'),
            ));
          }
        }
        return items;
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppThemeV2.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: auth.hasActiveCompany ? AppThemeV2.primary.withValues(alpha: 0.4) : AppThemeV2.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_outlined, size: 18, color: AppThemeV2.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: AppThemeV2.textMuted),
          ],
        ),
      ),
    );
  }
}
