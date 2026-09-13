import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../features/dashboard/widgets/dashboard_quick_actions.dart';
import '../../features/dashboard/widgets/dashboard_stat_card_v2.dart';
import '../../l10n/l10n_extension.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await api.adminUsersList();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _countRole(String role) => _users.where((u) => u['role']?.toString() == role).length;

  int get _activeCount => _users.where((u) => u['active'] != false).length;

  int get _hrCount => _countRole('HR_USER') + _countRole('HR_SUPERVISOR') + _countRole('HR_MANAGER');

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('admin.dashboardTitle'),
            subtitle: context.t('admin.dashboardSubtitle'),
            icon: Icons.admin_panel_settings_outlined,
            showRefresh: true,
            onRefresh: _load,
          ),
          const Gap(16),
          HrLocalDataBanner(
            title: context.t('admin.accountsBanner'),
            hint: context.t('admin.accountsBannerHint'),
          ),
          const Gap(20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else ...[
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: cols == 1 ? 2.4 : 1.55,
                  children: [
                    DashboardStatCardV2(
                      title: context.t('admin.totalUsers'),
                      subtitle: context.t('admin.allAccounts'),
                      value: _users.length,
                      icon: Icons.people_outline_rounded,
                      tone: StatToneV2.primary,
                      onTap: () => context.go(AppRoutes.adminUsers),
                    ),
                    DashboardStatCardV2(
                      title: context.t('admin.activeUsers'),
                      subtitle: context.t('admin.canLogin'),
                      value: _activeCount,
                      icon: Icons.verified_user_outlined,
                      tone: StatToneV2.success,
                      onTap: () => context.go(AppRoutes.adminUsers),
                    ),
                    DashboardStatCardV2(
                      title: context.t('admin.hrUsers'),
                      subtitle: 'HR User + Manager',
                      value: _hrCount,
                      icon: Icons.badge_outlined,
                      tone: StatToneV2.info,
                      onTap: () => context.go(AppRoutes.adminUsers),
                    ),
                    DashboardStatCardV2(
                      title: context.t('admin.employees'),
                      subtitle: context.t('admin.employeeRole'),
                      value: _countRole('EMPLOYEE'),
                      icon: Icons.person_outline_rounded,
                      tone: StatToneV2.warning,
                      onTap: () => context.go(AppRoutes.adminUsers),
                    ),
                  ],
                );
              },
            ),
            const Gap(28),
            Text(context.t('admin.quickActions'), style: AppThemeV2.headline.copyWith(fontSize: 18)),
            const Gap(4),
            Text(context.t('admin.quickActionsSub'), style: AppThemeV2.caption),
            const Gap(14),
            DashboardQuickActions(
              actions: [
                DashboardQuickAction(
                  label: context.t('admin.usersList'),
                  description: context.t('admin.usersListDesc'),
                  icon: Icons.people_outline_rounded,
                  route: AppRoutes.adminUsers,
                  tone: QuickActionTone.primary,
                ),
                DashboardQuickAction(
                  label: context.t('admin.createUser'),
                  description: context.t('admin.createUserDesc'),
                  icon: Icons.person_add_alt_1_outlined,
                  route: AppRoutes.adminCreateUser,
                  tone: QuickActionTone.success,
                ),
                DashboardQuickAction(
                  label: context.t('admin.hrUsers'),
                  description: context.t('admin.hrUsersDesc'),
                  icon: Icons.badge_outlined,
                  route: AppRoutes.adminUsers,
                  tone: QuickActionTone.info,
                  badge: _hrCount > 0 ? '$_hrCount' : null,
                ),
                DashboardQuickAction(
                  label: context.t('admin.disabledAccounts'),
                  description: context.t('admin.disabledAccountsDesc'),
                  icon: Icons.person_off_outlined,
                  route: AppRoutes.adminUsers,
                  tone: QuickActionTone.warning,
                  badge: (_users.length - _activeCount) > 0 ? '${_users.length - _activeCount}' : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
