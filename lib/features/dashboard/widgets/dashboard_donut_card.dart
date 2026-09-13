import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import 'dashboard_chart_models.dart';
import '../../../l10n/l10n_extension.dart';

class DashboardDonutCard extends StatelessWidget {
  const DashboardDonutCard({
    super.key,
    required this.title,
    required this.titleAr,
    required this.slices,
    this.onRefresh,
  });

  final String title;
  final String titleAr;
  final List<ChartSliceData> slices;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);
    final displaySlices = total == 0
        ? [ChartSliceData(label: 'No data', labelAr: context.t('dash.noData'), count: 1, color: AppColors.border)]
        : slices;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textMuted),
                ),
            ],
          ),
          SizedBox(
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    startDegreeOffset: -90,
                    sections: _buildSections(displaySlices, total),
                    pieTouchData: PieTouchData(enabled: !kIsWeb),
                  ),
                  duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 150),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleAr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (title != titleAr)
                      Text(
                        title,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: displaySlices.map((s) => _LegendItem(slice: s, total: total)).toList(),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(List<ChartSliceData> data, int total) {
    return data.map((slice) {
      final pct = total > 0 ? (slice.count / total * 100) : 0.0;
      return PieChartSectionData(
        value: slice.count == 0 ? 0.001 : slice.count.toDouble(),
        color: slice.color,
        radius: 34,
        title: total > 0 ? '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%\n${slice.count}' : '',
        titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
        badgeWidget: null,
      );
    }).toList();
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.slice, required this.total});

  final ChartSliceData slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (slice.count / total * 100) : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          '${slice.labelAr} (${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%) ${slice.count}',
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
