import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/glass_card.dart';
import 'dashboard_chart_models.dart';

class DashboardExceptionsChartV2 extends StatelessWidget {
  const DashboardExceptionsChartV2({
    super.key,
    required this.points,
    this.onRefresh,
  });

  final List<TrendPointData> points;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final maxY = _maxValue(points);
    final labels = points
        .map((p) => p.date.length >= 10 ? p.date.substring(5) : p.date)
        .toList();

    return GlassCard(
      animated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.t('chart.exceptionsTitle'), style: AppThemeV2.title)),
              if (onRefresh != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppThemeV2.textMuted),
                ),
            ],
          ),
          const Gap(12),
          Row(
            children: [
              _LineLegend(color: AppThemeV2.info, label: context.t('chart.absent')),
              const Gap(16),
              _LineLegend(color: AppThemeV2.success, label: context.t('chart.earlyLeave')),
              const Gap(16),
              _LineLegend(color: AppThemeV2.warning, label: context.t('chart.late')),
            ],
          ),
          const Gap(16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipBorder: const BorderSide(color: AppThemeV2.border),
                    getTooltipColor: (_) => AppThemeV2.surface,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final color = spot.bar.color ?? AppThemeV2.textPrimary;
                      return LineTooltipItem(
                        '${spot.y.toInt()}',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 5 : 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppThemeV2.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: maxY > 0 ? maxY / 5 : 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppThemeV2.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppThemeV2.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildLine(
                    points.map((p) => p.absent.toDouble()).toList(),
                    AppThemeV2.info,
                  ),
                  _buildLine(
                    points.map((p) => p.earlyLeave.toDouble()).toList(),
                    AppThemeV2.success,
                  ),
                  _buildLine(
                    points.map((p) => p.late.toDouble()).toList(),
                    AppThemeV2.warning,
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 2,
          strokeColor: AppThemeV2.surface,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  double _maxValue(List<TrendPointData> pts) {
    var max = 1.0;
    for (final p in pts) {
      final candidates = [max, p.absent.toDouble(), p.late.toDouble(), p.earlyLeave.toDouble()];
      max = candidates.reduce((a, b) => a > b ? a : b);
    }
    return max.ceilToDouble() + 1;
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
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const Gap(6),
        Text(label, style: AppThemeV2.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}
