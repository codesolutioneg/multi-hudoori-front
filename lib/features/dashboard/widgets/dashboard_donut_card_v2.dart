import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/glass_card.dart';
import 'dashboard_chart_models.dart';

class DashboardDonutCardV2 extends StatefulWidget {
  const DashboardDonutCardV2({
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
  State<DashboardDonutCardV2> createState() => _DashboardDonutCardV2State();
}

class _DashboardDonutCardV2State extends State<DashboardDonutCardV2> {
  int? _touchedIndex;

  bool get _hasValidTouch =>
      _touchedIndex != null && _touchedIndex! >= 0;

  ChartSliceData? _selectedSlice(List<ChartSliceData> slices) {
    final index = _touchedIndex;
    if (index == null || index < 0 || index >= slices.length) return null;
    return slices[index];
  }

  void _setTouchedIndex(int? index) {
    if (index != null && index < 0) index = null;
    setState(() => _touchedIndex = index);
  }

  static const List<Color> _defaultPalette = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.slices.fold<int>(0, (sum, s) => sum + s.count);
    final hasData = total > 0;

    if (!hasData) {
      return GlassCard(
        animated: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const Gap(8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _DonutEmptyState(
                    chartTitle: _localizedTitle(context),
                    maxHeight: constraints.maxHeight,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    final displaySlices = widget.slices.asMap().entries.map((e) {
      final fallback = _defaultPalette[e.key % _defaultPalette.length];
      final color = e.value.color == const Color(0xFF94A3B8) ? fallback : e.value.color;
      return ChartSliceData(
        label: e.value.label,
        labelAr: e.value.labelAr,
        count: e.value.count,
        color: color,
      );
    }).toList();

    final selected = _selectedSlice(displaySlices);

    return GlassCard(
      animated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Gap(12),
          SizedBox(
            height: 172,
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          startDegreeOffset: -90,
                          sections: _buildSections(displaySlices, total),
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback: (event, response) {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                _setTouchedIndex(null);
                                return;
                              }
                              _setTouchedIndex(
                                response.touchedSection!.touchedSectionIndex,
                              );
                            },
                          ),
                        ),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                      ),
                      _DonutCenter(
                        total: total,
                        selected: selected,
                      ),
                    ],
                  ),
                ),
                const Gap(10),
                Expanded(
                  flex: 10,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: displaySlices
                        .asMap()
                        .entries
                        .map(
                          (e) => _LegendItem(
                            slice: e.value,
                            total: total,
                            selected: _hasValidTouch && _touchedIndex == e.key,
                            onHover: () => _setTouchedIndex(e.key),
                            onExit: () => _setTouchedIndex(null),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localizedTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n.isAr ? widget.titleAr : widget.title;
  }

  Widget _buildHeader(BuildContext context) {
    final displayTitle = _localizedTitle(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayTitle, style: AppThemeV2.title),
              if (widget.title != widget.titleAr)
                Text(
                  AppLocalizations.of(context).isAr ? widget.title : widget.titleAr,
                  style: AppThemeV2.caption.copyWith(fontSize: 11),
                ),
            ],
          ),
        ),
        if (widget.onRefresh != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppThemeV2.textMuted),
          ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(List<ChartSliceData> data, int total) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final slice = entry.value;
      final pct = total > 0 ? (slice.count / total * 100) : 0.0;
      final isSmall = pct < 8;
      final isSelected = _hasValidTouch && _touchedIndex == index;
      final isDimmed = _hasValidTouch && !isSelected;

      return PieChartSectionData(
        value: slice.count == 0 ? 0.001 : slice.count.toDouble(),
        color: isDimmed ? slice.color.withValues(alpha: 0.28) : slice.color,
        radius: isSelected ? 34 : 30,
        title: total > 0 && !isSmall && !isDimmed
            ? '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%'
            : '',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.62,
        borderSide: const BorderSide(color: Colors.white, width: 2),
      );
    }).toList();
  }
}

class _DonutEmptyState extends StatelessWidget {
  const _DonutEmptyState({
    required this.chartTitle,
    required this.maxHeight,
  });

  final String chartTitle;
  final double maxHeight;

  bool get _compact => maxHeight < 220;

  @override
  Widget build(BuildContext context) {
    final ringSize = _compact ? 76.0 : 96.0;
    final iconSize = _compact ? 20.0 : 24.0;
    final innerIcon = _compact ? 40.0 : 48.0;
    final vPad = _compact ? 10.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppThemeV2.surfaceElevated,
            AppThemeV2.surface,
          ],
        ),
        border: Border.all(color: AppThemeV2.border.withValues(alpha: 0.8)),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(ringSize, ringSize),
                      painter: _DashedDonutPainter(stroke: _compact ? 9 : 11),
                    ),
                    Container(
                      width: innerIcon,
                      height: innerIcon,
                      decoration: BoxDecoration(
                        color: AppThemeV2.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppThemeV2.border),
                        boxShadow: AppThemeV2.cardShadow,
                      ),
                      child: Icon(
                        Icons.insights_outlined,
                        size: iconSize,
                        color: AppThemeV2.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(_compact ? 8 : 12),
              Text(
                context.t('chart.noDataDetail'),
                style: AppThemeV2.title.copyWith(fontSize: _compact ? 13 : 15),
                textAlign: TextAlign.center,
              ),
              if (!_compact) ...[
                const Gap(4),
                Text(
                  context.t('chart.noDataFor', {'title': chartTitle}),
                  style: AppThemeV2.caption.copyWith(height: 1.4, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Gap(_compact ? 8 : 10),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _compact ? 8 : 12,
                  vertical: _compact ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  color: AppThemeV2.primarySoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded, size: _compact ? 12 : 14, color: AppThemeV2.primary),
                    const Gap(5),
                    Text(
                      _compact ? context.t('chart.afterSyncShort') : context.t('chart.afterSync'),
                      style: AppThemeV2.caption.copyWith(
                        color: AppThemeV2.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: _compact ? 10 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedDonutPainter extends CustomPainter {
  const _DashedDonutPainter({this.stroke = 11});

  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke * 0.85;

    final track = Paint()
      ..color = AppThemeV2.border.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = AppThemeV2.textMuted.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 8;
    const sweep = (2 * 3.1415926535) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.1415926535 / 2 + i * sweep,
        sweep * 0.45,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedDonutPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

class _DonutCenter extends StatelessWidget {
  const _DonutCenter({
    required this.total,
    required this.selected,
  });

  final int total;
  final ChartSliceData? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (selected != null) {
      final pct = total > 0 ? (selected!.count / total * 100) : 0.0;
      final label = l10n.isAr ? selected!.labelAr : selected!.label;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%',
            style: AppThemeV2.statValue.copyWith(fontSize: 22, color: selected!.color),
          ),
          const Gap(2),
          Text(
            label,
            style: AppThemeV2.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedCounter(
          value: total,
          style: AppThemeV2.statValue.copyWith(fontSize: 24),
        ),
        Text(context.t('chart.total'), style: AppThemeV2.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.slice,
    required this.total,
    required this.selected,
    required this.onHover,
    required this.onExit,
  });

  final ChartSliceData slice;
  final int total;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pct = total > 0 ? slice.count / total : 0.0;
    final pctLabel = total > 0 ? (pct * 100).toStringAsFixed(pct >= 0.1 ? (pct >= 10 ? 0 : 1) : 1) : '0';
    final label = l10n.isAr ? slice.labelAr : slice.label;

    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onExit(),
      child: AnimatedContainer(
        duration: AppThemeV2.fast,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? slice.color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? slice.color.withValues(alpha: 0.25) : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: slice.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    label,
                    style: AppThemeV2.body.copyWith(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$pctLabel%',
                  style: AppThemeV2.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: slice.color,
                  ),
                ),
              ],
            ),
            const Gap(6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppThemeV2.surfaceElevated,
                color: slice.color,
              ),
            ),
            const Gap(2),
            Text(
              context.t('chart.items', {'n': slice.count}),
              style: AppThemeV2.caption.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
