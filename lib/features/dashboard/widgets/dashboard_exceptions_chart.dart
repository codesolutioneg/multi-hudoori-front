import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import 'dashboard_chart_models.dart';
import '../../../l10n/l10n_extension.dart';

class DashboardExceptionsChart extends StatelessWidget {
  const DashboardExceptionsChart({
    super.key,
    required this.points,
    this.onRefresh,
  });

  final List<TrendPointData> points;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final maxY = _maxValue(points);
    final labels = points.map((p) => p.date.length >= 10 ? p.date.substring(5) : p.date).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('dash.exceptions'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
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
          SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _LineLegend(color: AppColors.info, label: context.t('dash.absent')),
              _LineLegend(color: AppColors.success, label: context.t('dash.earlyLeave')),
              _LineLegend(color: AppColors.warning, label: context.t('dash.late')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(enabled: !kIsWeb),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 5 : 1,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withValues(alpha: 0.6), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY > 0 ? maxY / 5 : 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i], style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _line(points.map((p) => p.absent.toDouble()).toList(), AppColors.info),
                  _line(points.map((p) => p.earlyLeave.toDouble()).toList(), AppColors.success),
                  _line(points.map((p) => p.late.toDouble()).toList(), AppColors.warning),
                ],
              ),
              duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 150),
            ),
          ),
        ],
      ),
    );
  }

  double _maxValue(List<TrendPointData> pts) {
    var max = 1.0;
    for (final p in pts) {
      max = [max, p.absent.toDouble(), p.late.toDouble(), p.earlyLeave.toDouble()].reduce((a, b) => a > b ? a : b);
    }
    return max.ceilToDouble();
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
      isCurved: !kIsWeb,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _LineLegend extends StatelessWidget {
  const _LineLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
