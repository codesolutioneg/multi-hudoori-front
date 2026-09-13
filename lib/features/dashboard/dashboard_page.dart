import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/alert_banner.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/stat_card.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'widgets/dashboard_chart_models.dart';
import 'widgets/dashboard_donut_card.dart';
import 'widgets/dashboard_exceptions_chart.dart';
import 'widgets/dashboard_realtime_panel.dart';
import 'widgets/dashboard_skeleton.dart';
import '../../l10n/l10n_extension.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _charts = {};
  bool _statsLoading = true;
  bool _chartsLoading = true;
  bool _initialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isHr(AuthState auth) => auth.roles.isHrUser || auth.roles.isHrManager;

  Future<void> _load({bool refresh = false}) async {
    final isHr = _isHr(context.read<AuthCubit>().state);
    if (!refresh) {
      setState(() {
        _statsLoading = true;
        _chartsLoading = isHr;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final stats = await api.dashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _initialLoad = false;
        _error = context.t('dash.statsFailed');
      });
    }

    if (!isHr) {
      if (mounted) setState(() => _chartsLoading = false);
      return;
    }

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
        _error ??= context.t('dash.chartsFailed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final isHr = _isHr(auth);
        final showFullSkeleton = _initialLoad && (_statsLoading || (isHr && _chartsLoading));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: context.t('dash.greeting', {
                  'name': auth.employeeName.isNotEmpty
                      ? auth.employeeName
                      : auth.user?.name ?? '',
                }),
                subtitle: auth.employeeCode.isNotEmpty
                    ? context.t('dash.codeSubtitle', {'code': auth.employeeCode})
                    : context.t('dash.title'),
                icon: Icons.dashboard_outlined,
                showRefresh: !_statsLoading && !_chartsLoading,
                onRefresh: () => _load(refresh: true),
              ),
              if (auth.profileWarning != null) ...[
                const SizedBox(height: 16),
                AlertBanner(message: auth.profileWarning!, tone: AlertBannerTone.warning),
              ],
              if (auth.menus.length <= 1) ...[
                const SizedBox(height: 16),
                AlertBanner(
                  tone: AlertBannerTone.warning,
                  message: context.t('dash.menusMissing'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                AlertBanner(
                  tone: AlertBannerTone.error,
                  message: _error!,
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                      TextButton(onPressed: () => _load(refresh: true), child: Text(context.t('dash.retry'))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (showFullSkeleton)
                DashboardSkeleton(showCharts: isHr)
              else ...[
                if (isHr) ...[
                  if (_chartsLoading)
                    const DashboardSkeleton(showCharts: true)
                  else ...[
                    RepaintBoundary(child: _buildChartsGrid(context)),
                    const SizedBox(height: 16),
                    RepaintBoundary(child: _buildBottomSection()),
                    const SizedBox(height: 16),
                  ],
                ],
                if (_statsLoading)
                  const DashboardSkeleton(showCharts: false)
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 800 ? 3 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          if (isHr) ...[
                            StatCard(
                              title: context.t('dash.employees'),
                              value: '${_stats['employeesCount'] ?? _stats['employees'] ?? 0}',
                              icon: Icons.people_outline_rounded,
                              tone: StatCardTone.primary,
                            ),
                            StatCard(
                              title: context.t('dash.todayAtt'),
                              value: '${_stats['attendanceToday'] ?? 0}',
                              icon: Icons.fact_check_outlined,
                              tone: StatCardTone.success,
                            ),
                            StatCard(
                              title: context.t('dash.draftPayrolls'),
                              value: '${_stats['payrollsDraft'] ?? 0}',
                              icon: Icons.payments_outlined,
                              tone: StatCardTone.warning,
                            ),
                          ] else
                            StatCard(
                              title: context.t('dash.myRecords'),
                              value: '${_stats['myAttendanceMonth'] ?? 0}',
                              icon: Icons.schedule_outlined,
                              tone: StatCardTone.info,
                            ),
                        ],
                      );
                    },
                  ),
              ],
              const SizedBox(height: 16),
              AlertBanner(
                tone: AlertBannerTone.info,
                message: isHr
                    ? context.t('dash.hrDataNote')
                    : context.t('dash.employeeDataNote'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartsGrid(BuildContext context) {
    final approvals = slicesFromJson(_charts['approvals']);
    final schedule = slicesFromJson(_charts['schedule']);
    final deviceStatus = slicesFromJson(_charts['deviceStatus']);
    final attendance = slicesFromJson(_charts['attendance']);

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 700 ? 2 : 1);
        final charts = [
          DashboardDonutCard(
            title: 'Approvals',
            titleAr: context.t('dash.approvals'),
            slices: approvals,
            onRefresh: () => _load(refresh: true),
          ),
          DashboardDonutCard(
            title: 'Schedule',
            titleAr: context.t('dash.schedule'),
            slices: schedule,
            onRefresh: () => _load(refresh: true),
          ),
          DashboardDonutCard(
            title: 'Device Status',
            titleAr: context.t('dash.deviceStatus'),
            slices: deviceStatus,
            onRefresh: () => _load(refresh: true),
          ),
          DashboardDonutCard(
            title: 'Attendance',
            titleAr: context.t('dash.present'),
            slices: attendance,
            onRefresh: () => _load(refresh: true),
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: cols == 1 ? 0.92 : 0.82,
          ),
          itemCount: charts.length,
          itemBuilder: (_, i) => charts[i],
        );
      },
    );
  }

  Widget _buildBottomSection() {
    final trend = trendFromJson(_charts['exceptionsTrend']);
    final punches = (_charts['recentPunches'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: DashboardRealtimePanel(punches: punches, onRefresh: () => _load(refresh: true))),
              const SizedBox(width: 12),
              Expanded(child: DashboardExceptionsChart(points: trend, onRefresh: () => _load(refresh: true))),
            ],
          );
        }
        return Column(
          children: [
            DashboardRealtimePanel(punches: punches, onRefresh: () => _load(refresh: true)),
            const SizedBox(height: 12),
            DashboardExceptionsChart(points: trend, onRefresh: () => _load(refresh: true)),
          ],
        );
      },
    );
  }
}
