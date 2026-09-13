import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../features/dashboard/widgets/dashboard_quick_actions.dart';
import '../../features/dashboard/widgets/dashboard_stat_card_v2.dart';
import '../../l10n/l10n_extension.dart';

class HrDashboardPage extends StatefulWidget {
  const HrDashboardPage({super.key});

  @override
  State<HrDashboardPage> createState() => _HrDashboardPageState();
}

class _HrDashboardPageState extends State<HrDashboardPage> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await api.dashboardStats();
      if (mounted)
        setState(() {
          _stats = stats;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('hrDash.title'),
            subtitle: context.t('hrDash.subtitle'),
            icon: Icons.dashboard_outlined,
            showRefresh: true,
            onRefresh: _load,
          ),
          const Gap(20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1000
                    ? 4
                    : (c.maxWidth >= 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: cols == 1 ? 2.4 : 1.55,
                  children: [
                    DashboardStatCardV2(
                      title: context.t('employees.title'),
                      subtitle: context.t('stat.activeEmployeesSub'),
                      value:
                          (_stats['employeesCount'] ?? _stats['employees'] ?? 0)
                              as int,
                      icon: Icons.people_outline_rounded,
                      tone: StatToneV2.primary,
                      onTap: () => context.go(AppRoutes.hrEmployees),
                    ),
                    DashboardStatCardV2(
                      title: context.t('stat.attendanceToday'),
                      value: (_stats['attendanceToday'] ?? 0) as int,
                      icon: Icons.fact_check_outlined,
                      tone: StatToneV2.success,
                      onTap: () => context.go(AppRoutes.hrAttendance),
                    ),
                    DashboardStatCardV2(
                      title: context.t('stat.pendingRequests'),
                      value: (_stats['pendingRequests'] ?? 0) as int,
                      icon: Icons.pending_actions_outlined,
                      tone: StatToneV2.info,
                      onTap: () => context.go(AppRoutes.requests),
                    ),
                    DashboardStatCardV2(
                      title: context.t('stat.payrollsDraft'),
                      value: (_stats['payrollsDraft'] ?? 0) as int,
                      icon: Icons.payments_outlined,
                      tone: StatToneV2.warning,
                      onTap: () => context.go(AppRoutes.hrPayroll),
                    ),
                  ],
                );
              },
            ),
            const Gap(28),
            Text(
              context.t('hrDash.shortcuts'),
              style: AppThemeV2.headline.copyWith(fontSize: 18),
            ),
            const Gap(4),
            Text(context.t('hrDash.shortcutsSub'), style: AppThemeV2.caption),
            const Gap(14),
            DashboardQuickActions(
              actions: DashboardQuickActions.hrActions(
                context,
                pendingRequests:
                    (_stats['pendingRequests'] as num?)?.toInt() ?? 0,
                hiringUnread: (_stats['hiringUnread'] as num?)?.toInt() ?? 0,
                unreadAbsences: (_stats['absentUnread'] as num?)?.toInt() ?? 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
