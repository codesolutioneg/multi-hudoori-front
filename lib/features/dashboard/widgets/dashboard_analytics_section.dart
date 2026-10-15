import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import 'dashboard_chart_models.dart';
import 'dashboard_donut_card_v2.dart';
import 'dashboard_exceptions_chart_v2.dart';
import 'dashboard_realtime_panel_v2.dart';
import 'dashboard_section_header.dart';

class _ChartConfig {
  const _ChartConfig({
    required this.title,
    required this.titleAr,
    required this.slices,
  });

  final String title;
  final String titleAr;
  final List<ChartSliceData> slices;
}

/// Donut charts + optional live activity panels (shared by `/dashboard` and `/hr/dashboard`).
class DashboardAnalyticsSection extends StatelessWidget {
  const DashboardAnalyticsSection({
    super.key,
    required this.charts,
    required this.onRefresh,
    this.showLiveActivity = true,
  });

  final Map<String, dynamic> charts;
  final VoidCallback onRefresh;
  final bool showLiveActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionHeader(
          title: context.t('dash.analytics'),
          subtitle: context.t('dash.analyticsSub'),
        ),
        const Gap(14),
        _DonutChartsGrid(charts: charts, onRefresh: onRefresh),
        if (showLiveActivity) ...[
          const Gap(36),
          DashboardSectionHeader(
            title: context.t('dash.liveActivity'),
            subtitle: context.t('dash.liveActivitySub'),
          ),
          const Gap(14),
          _LiveActivitySection(charts: charts, onRefresh: onRefresh),
        ],
      ],
    );
  }
}

class _DonutChartsGrid extends StatelessWidget {
  const _DonutChartsGrid({required this.charts, required this.onRefresh});

  final Map<String, dynamic> charts;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configs = [
      _ChartConfig(
        title: 'Approvals',
        titleAr: l10n.t('chart.approvals'),
        slices: slicesFromJson(charts['approvals']),
      ),
      _ChartConfig(
        title: 'Schedule',
        titleAr: l10n.t('chart.schedule'),
        slices: slicesFromJson(charts['schedule']),
      ),
      _ChartConfig(
        title: 'Device Status',
        titleAr: l10n.t('chart.deviceStatus'),
        slices: slicesFromJson(charts['deviceStatus']),
      ),
      _ChartConfig(
        title: 'Attendance',
        titleAr: l10n.t('chart.attendance'),
        slices: slicesFromJson(charts['attendance']),
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
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final chart = configs[index];
            return DashboardDonutCardV2(
                  title: chart.title,
                  titleAr: chart.titleAr,
                  slices: chart.slices,
                  onRefresh: onRefresh,
                )
                .animate(delay: Duration(milliseconds: index * 80))
                .fadeIn(duration: 450.ms)
                .scaleXY(begin: 0.97, end: 1.0, duration: 450.ms);
          },
        );
      },
    );
  }
}

class _LiveActivitySection extends StatelessWidget {
  const _LiveActivitySection({required this.charts, required this.onRefresh});

  final Map<String, dynamic> charts;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final trend = trendFromJson(charts['exceptionsTrend']);
    final punches =
        (charts['recentPunches'] as List?)
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
                    onRefresh: onRefresh,
                  ),
                ),
              ),
              const Gap(14),
              Expanded(
                child: SizedBox(
                  height: panelHeight,
                  child: DashboardExceptionsChartV2(
                    points: trend,
                    onRefresh: onRefresh,
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
                onRefresh: onRefresh,
              ),
            ),
            const Gap(14),
            SizedBox(
              height: panelHeight,
              child: DashboardExceptionsChartV2(
                points: trend,
                onRefresh: onRefresh,
              ),
            ),
          ],
        );
      },
    );
  }
}
