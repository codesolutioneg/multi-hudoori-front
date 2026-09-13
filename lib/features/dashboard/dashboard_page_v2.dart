import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/di/injection.dart';
import '../../core/platform/mobile_platform.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'widgets/dashboard_auto_sync_panel.dart';
import 'widgets/dashboard_chart_models.dart';
import 'widgets/dashboard_donut_card_v2.dart';
import 'widgets/dashboard_exceptions_chart_v2.dart';
import 'widgets/dashboard_hero_header.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/dashboard_realtime_panel_v2.dart';
import 'widgets/dashboard_section_header.dart';
import 'widgets/dashboard_stat_card_v2.dart';

class DashboardPageV2 extends StatefulWidget {
  const DashboardPageV2({super.key});

  @override
  State<DashboardPageV2> createState() => _DashboardPageV2State();
}

class _DashboardPageV2State extends State<DashboardPageV2> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _charts = {};
  int _employeeMonthAttendance = 0;
  bool _statsLoading = true;
  bool _chartsLoading = true;
  bool _refreshing = false;
  bool _initialLoad = true;
  String? _error;

  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    // Localizations / InheritedWidgets are not safe in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  bool _isHr(AuthState auth) => auth.roles.isHrUser || auth.roles.isHrManager;

  bool _isHrManager(AuthState auth) => auth.roles.isHrManager;

  bool _isBranchManager(AuthState auth) => auth.roles.isBranchManager;

  bool _showBranchDashboard(AuthState auth) =>
      _isBranchManager(auth) && !_isHr(auth);

  String _monthRangeIso() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return iso(start);
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load({bool refresh = false}) async {
    final auth = context.read<AuthCubit>().state;
    // Native mobile is employee self-service; don't drive HR chart loads there.
    final isHr = !isNativeMobile && _isHr(auth);
    final l10n = AppLocalizations.of(context);

    if (!refresh) {
      setState(() {
        _statsLoading = true;
        _chartsLoading = isHr;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }

    try {
      final stats = await api.dashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
        _initialLoad = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _initialLoad = false;
        _error = l10n.t('dash.statsLoadError');
      });
    }

    if (!isHr) {
      try {
        final records = await api.myAttendance(
          dateFrom: _monthRangeIso(),
          dateTo: _todayIso(),
        );
        if (mounted) setState(() => _employeeMonthAttendance = records.length);
      } catch (_) {
        if (mounted) setState(() => _employeeMonthAttendance = 0);
      }
      if (mounted) setState(() => _chartsLoading = false);
    } else {
      try {
        final charts = await api.dashboardCharts();
        if (!mounted) return;
        setState(() {
          _charts = charts;
          _chartsLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _chartsLoading = false;
          _error ??= l10n.t('dash.chartsLoadError');
        });
      }
    }

    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final isHr = !isNativeMobile && _isHr(auth);
        final isHrManager = !isNativeMobile && _isHrManager(auth);
        final isBranch = !isNativeMobile && _showBranchDashboard(auth);
        final isLoading = _statsLoading || (isHr && _chartsLoading);

        // 24 a side costs a phone 13% of its width before any card starts.
        final compact = MediaQuery.sizeOf(context).width < 480;

        return SelectionArea(
          child: ColoredBox(
            color: AppThemeV2.background,
            child: SingleChildScrollView(
              padding: compact
                  ? const EdgeInsets.fromLTRB(14, 16, 14, 28)
                  : const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DashboardHeroHeader(
                        auth: auth,
                        lastUpdated: _lastUpdated,
                        isRefreshing: _refreshing,
                        onRefresh: () => _load(refresh: true),
                      ),
                      const Gap(28),
                      if (auth.profileWarning != null) ...[
                        _buildAlertBanner(
                          message: auth.profileWarning!,
                          tone: _AlertTone.warning,
                        ),
                        const Gap(16),
                      ],
                      if (auth.menus.length <= 1) ...[
                        _buildAlertBanner(
                          message: context.t('dash.menusNotLoaded'),
                          tone: _AlertTone.warning,
                        ),
                        const Gap(16),
                      ],
                      if (_error != null) ...[
                        _buildAlertBanner(
                          message: _error!,
                          tone: _AlertTone.error,
                          onRetry: () => _load(refresh: true),
                        ),
                        const Gap(16),
                      ],
                      Skeletonizer(
                        enabled: _initialLoad && isLoading,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DashboardSectionHeader(
                              title: context.t('dash.quickActions'),
                              subtitle: isHr
                                  ? context.t('dash.quickActionsHr')
                                  : isBranch
                                  ? context.t('dash.quickActionsBranch')
                                  : context.t('dash.quickActionsEmployee'),
                            ),
                            const Gap(14),
                            DashboardQuickActions(
                              actions: isHr
                                  ? DashboardQuickActions.hrActions(
                                      context,
                                      pendingRequests:
                                          (_stats['pendingRequests'] as num?)
                                              ?.toInt() ??
                                          0,
                                      healthCertAlerts:
                                          (_stats['healthCertAlerts'] as num?)
                                              ?.toInt() ??
                                          0,
                                      hiringUnread:
                                          (_stats['hiringUnread'] as num?)
                                              ?.toInt() ??
                                          0,
                                      unreadAbsences:
                                          (_stats['absentUnread'] as num?)
                                              ?.toInt() ??
                                          0,
                                    )
                                  : isBranch
                                  ? DashboardQuickActions.branchManagerActions(
                                      context,
                                      hiringUnread:
                                          (_stats['hiringUnread'] as num?)
                                              ?.toInt() ??
                                          0,
                                    )
                                  : DashboardQuickActions.employeeActions(
                                      context,
                                    ),
                            ),
                            const Gap(32),
                            DashboardSectionHeader(
                              title: context.t('dash.kpis'),
                              subtitle: isHr
                                  ? context.t('dash.kpisHr')
                                  : isBranch
                                  ? context.t('dash.kpisBranch')
                                  : context.t('dash.kpisEmployee'),
                            ),
                            const Gap(14),
                            _buildStatsGrid(context, isHr, isBranch),
                            if (isHr) ...[
                              const Gap(36),
                              DashboardSectionHeader(
                                title: context.t('dash.analytics'),
                                subtitle: context.t('dash.analyticsSub'),
                              ),
                              const Gap(14),
                              _buildChartsGrid(context),
                              const Gap(36),
                              DashboardSectionHeader(
                                title: context.t('dash.liveActivity'),
                                subtitle: context.t('dash.liveActivitySub'),
                              ),
                              const Gap(14),
                              _buildBottomSection(),
                              if (isHrManager) ...[
                                const Gap(32),
                                const DashboardAutoSyncPanel(),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isHr, bool isBranch) {
    final l10n = AppLocalizations.of(context);
    final configs = isHr
        ? <_StatConfig>[
            _StatConfig(
              title: l10n.t('stat.activeEmployees'),
              subtitle: l10n.t('stat.activeEmployeesSub'),
              value: _stats['employeesCount'] ?? _stats['employees'] ?? 0,
              icon: Icons.people_outline_rounded,
              tone: StatToneV2.primary,
              route: AppRoutes.hrEmployees,
            ),
            _StatConfig(
              title: l10n.t('stat.attendanceToday'),
              subtitle: l10n.t('stat.attendanceTodaySub'),
              value: _stats['attendanceToday'] ?? 0,
              icon: Icons.fact_check_outlined,
              tone: StatToneV2.success,
              route: AppRoutes.hrAttendance,
            ),
            _StatConfig(
              title: l10n.t('stat.payrollsDraft'),
              subtitle: l10n.t('stat.payrollsDraftSub'),
              value: _stats['payrollsDraft'] ?? 0,
              icon: Icons.payments_outlined,
              tone: StatToneV2.warning,
              route: AppRoutes.hrPayroll,
            ),
            _StatConfig(
              title: l10n.t('stat.pendingRequests'),
              subtitle: l10n.t('stat.pendingRequestsSub'),
              value: _stats['pendingRequests'] ?? 0,
              icon: Icons.pending_actions_outlined,
              tone: StatToneV2.info,
              route: AppRoutes.requests,
            ),
          ]
        : isBranch
        ? <_StatConfig>[
            _StatConfig(
              title: l10n.t('stat.newHiring'),
              subtitle: l10n.t('stat.newHiringSub'),
              value: _stats['hiringUnread'] ?? 0,
              icon: Icons.assignment_ind_outlined,
              tone: StatToneV2.primary,
              route: AppRoutes.hrHiringAppointments,
            ),
            _StatConfig(
              title: l10n.t('stat.attendanceToday'),
              subtitle: l10n.t('stat.attendanceTodaySub'),
              value: _stats['attendanceToday'] ?? 0,
              icon: Icons.fact_check_outlined,
              tone: StatToneV2.success,
            ),
          ]
        // A branch employee gets their own figures only. Every other tile on
        // this screen counts the whole company, which is not theirs to read.
        : <_StatConfig>[
            _StatConfig(
              title: l10n.t('stat.myAttendance'),
              subtitle: l10n.t('stat.myAttendanceSub'),
              value: _employeeMonthAttendance,
              icon: Icons.schedule_outlined,
              tone: StatToneV2.primary,
              route: AppRoutes.myAttendance,
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isHr
                ? crossCount.clamp(1, 4)
                : crossCount.clamp(1, 2),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            // Web keeps original aspect ratios; native mobile needs taller cells.
            childAspectRatio: crossCount == 1
                ? (isNativeMobile ? 1.9 : 2.4)
                : (isNativeMobile ? 1.45 : 1.55),
          ),
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final cfg = configs[index];
            return DashboardStatCardV2(
                  title: cfg.title,
                  subtitle: cfg.subtitle,
                  value: cfg.value,
                  icon: cfg.icon,
                  tone: cfg.tone,
                  onTap: cfg.route != null
                      ? () => context.go(cfg.route!)
                      : null,
                )
                .animate(delay: Duration(milliseconds: index * 80))
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.06, end: 0, duration: 400.ms);
          },
        );
      },
    );
  }

  Widget _buildChartsGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approvals = slicesFromJson(_charts['approvals']);
    final schedule = slicesFromJson(_charts['schedule']);
    final deviceStatus = slicesFromJson(_charts['deviceStatus']);
    final attendance = slicesFromJson(_charts['attendance']);

    final charts = [
      _ChartConfig(
        title: 'Approvals',
        titleAr: l10n.t('chart.approvals'),
        slices: approvals,
      ),
      _ChartConfig(
        title: 'Schedule',
        titleAr: l10n.t('chart.schedule'),
        slices: schedule,
      ),
      _ChartConfig(
        title: 'Device Status',
        titleAr: l10n.t('chart.deviceStatus'),
        slices: deviceStatus,
      ),
      _ChartConfig(
        title: 'Attendance',
        titleAr: l10n.t('chart.attendance'),
        slices: attendance,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 700
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: crossCount == 1 ? 1.05 : 0.95,
          ),
          itemCount: charts.length,
          itemBuilder: (context, index) {
            final chart = charts[index];
            return DashboardDonutCardV2(
                  title: chart.title,
                  titleAr: chart.titleAr,
                  slices: chart.slices,
                  onRefresh: () => _load(refresh: true),
                )
                .animate(delay: Duration(milliseconds: index * 80))
                .fadeIn(duration: 450.ms)
                .scaleXY(begin: 0.97, end: 1.0, duration: 450.ms);
          },
        );
      },
    );
  }

  Widget _buildBottomSection() {
    final trend = trendFromJson(_charts['exceptionsTrend']);
    final punches =
        (_charts['recentPunches'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    return LayoutBuilder(
      builder: (context, constraints) {
        const panelHeight = 380.0;

        if (constraints.maxWidth >= 960) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: panelHeight,
                  child: DashboardRealtimePanelV2(
                    punches: punches,
                    onRefresh: () => _load(refresh: true),
                  ),
                ),
              ),
              const Gap(14),
              Expanded(
                child: SizedBox(
                  height: panelHeight,
                  child: DashboardExceptionsChartV2(
                    points: trend,
                    onRefresh: () => _load(refresh: true),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              height: panelHeight,
              child: DashboardRealtimePanelV2(
                punches: punches,
                onRefresh: () => _load(refresh: true),
              ),
            ),
            const Gap(14),
            SizedBox(
              height: panelHeight,
              child: DashboardExceptionsChartV2(
                points: trend,
                onRefresh: () => _load(refresh: true),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertBanner({
    required String message,
    required _AlertTone tone,
    VoidCallback? onRetry,
  }) {
    final (bg, border, fg, icon) = switch (tone) {
      _AlertTone.warning => (
        const Color(0xFFFEF3C7),
        const Color(0xFFFDE68A),
        const Color(0xFF92400E),
        Icons.warning_amber_rounded,
      ),
      _AlertTone.error => (
        const Color(0xFFFEE2E2),
        const Color(0xFFFECACA),
        const Color(0xFF991B1B),
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const Gap(12),
          Expanded(
            child: Text(
              message,
              style: AppThemeV2.body.copyWith(color: fg, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                context.t('common.retry'),
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

enum _AlertTone { warning, error }

class _StatConfig {
  final String title;
  final String? subtitle;
  final int value;
  final IconData icon;
  final StatToneV2 tone;
  final String? route;

  _StatConfig({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
    this.subtitle,
    this.route,
  });
}

class _ChartConfig {
  final String title;
  final String titleAr;
  final List<ChartSliceData> slices;

  _ChartConfig({
    required this.title,
    required this.titleAr,
    required this.slices,
  });
}
