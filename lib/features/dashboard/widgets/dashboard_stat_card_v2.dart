import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/platform/mobile_platform.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/l10n_extension.dart';

enum StatToneV2 { primary, success, warning, info, danger }

enum StatCardLayout { horizontal, elevated }

class DashboardStatCardV2 extends StatefulWidget {
  const DashboardStatCardV2({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.tone = StatToneV2.primary,
    this.hint,
    this.trend,
    this.subtitle,
    this.onTap,
    this.layout = StatCardLayout.elevated,
  });

  final String title;
  final int value;
  final IconData icon;
  final StatToneV2 tone;
  final String? hint;
  final String? subtitle;
  final double? trend;
  final VoidCallback? onTap;
  final StatCardLayout layout;

  @override
  State<DashboardStatCardV2> createState() => _DashboardStatCardV2State();
}

class _DashboardStatCardV2State extends State<DashboardStatCardV2> {
  bool _hovered = false;

  (Color bg, Color fg, Color shadow) get _colors => switch (widget.tone) {
        StatToneV2.success => (
            const Color(0xFFD1FAE5),
            AppThemeV2.success,
            AppThemeV2.success,
          ),
        StatToneV2.warning => (
            const Color(0xFFFEF3C7),
            AppThemeV2.warning,
            AppThemeV2.warning,
          ),
        StatToneV2.info => (
            const Color(0xFFCFFAFE),
            AppThemeV2.info,
            AppThemeV2.info,
          ),
        StatToneV2.danger => (
            const Color(0xFFFEE2E2),
            AppThemeV2.danger,
            AppThemeV2.danger,
          ),
        StatToneV2.primary => (
            AppThemeV2.primarySoft,
            AppThemeV2.primary,
            AppThemeV2.primary,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, shadow) = _colors;
    final interactive = widget.onTap != null;

    final content = widget.layout == StatCardLayout.elevated
        ? _buildElevated(bg, fg)
        : _buildHorizontal(bg, fg, shadow);

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: GlassCard(
          animated: false,
          hoverScale: interactive ? 1.01 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              if (interactive && _hovered) ...[
                const Gap(12),
                Divider(height: 1, color: AppThemeV2.border.withValues(alpha: 0.8)),
                const Gap(8),
                Row(
                  children: [
                    Text(
                      context.t('dash.viewDetails'),
                      style: AppThemeV2.caption.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: fg),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElevated(Color bg, Color fg) {
    // Compact metrics only on native mobile — web keeps original spacing/type.
    final mobile = isNativeMobile;
    final iconBox = mobile ? 36.0 : 40.0;
    final iconGlyph = mobile ? 18.0 : 20.0;
    final valueSize = mobile ? 30.0 : 36.0;
    final afterTitle = mobile ? 10.0 : 14.0;
    final afterValue = mobile ? 4.0 : 6.0;
    final afterHint = mobile ? 2.0 : 4.0;
    final afterTrend = mobile ? 6.0 : 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                maxLines: mobile ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: AppThemeV2.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppThemeV2.textSecondary,
                ),
              ),
            ),
            if (mobile) const Gap(8),
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: fg, size: iconGlyph),
            ),
          ],
        ),
        Gap(afterTitle),
        AnimatedCounter(
          value: widget.value,
          style: AppThemeV2.statValue.copyWith(
            fontSize: valueSize,
            height: mobile ? 1.1 : null,
          ),
        ),
        if (widget.subtitle != null) ...[
          Gap(afterValue),
          Text(
            widget.subtitle!,
            maxLines: mobile ? 1 : null,
            overflow: mobile ? TextOverflow.ellipsis : TextOverflow.clip,
            style: AppThemeV2.caption,
          ),
        ],
        if (widget.hint != null) ...[
          Gap(afterHint),
          Text(
            widget.hint!,
            maxLines: mobile ? 1 : null,
            overflow: mobile ? TextOverflow.ellipsis : TextOverflow.clip,
            style: AppThemeV2.caption.copyWith(fontSize: 11),
          ),
        ],
        if (widget.trend != null) ...[
          Gap(afterTrend),
          _TrendRow(trend: widget.trend!),
        ],
      ],
    );
  }

  Widget _buildHorizontal(Color bg, Color fg, Color shadow) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: shadow.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(widget.icon, color: fg, size: 26),
        ),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: AppThemeV2.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppThemeV2.textSecondary,
                ),
              ),
              const Gap(6),
              AnimatedCounter(value: widget.value, style: AppThemeV2.statValue),
              if (widget.hint != null) ...[
                const Gap(4),
                Text(widget.hint!, style: AppThemeV2.caption.copyWith(fontSize: 11)),
              ],
              if (widget.trend != null) ...[
                const Gap(4),
                _TrendRow(trend: widget.trend!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          trend >= 0 ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: trend >= 0 ? AppThemeV2.success : AppThemeV2.danger,
        ),
        const Gap(4),
        Text(
          '${trend >= 0 ? '+' : ''}${(trend * 100).toStringAsFixed(0)}%',
          style: AppThemeV2.caption.copyWith(
            color: trend >= 0 ? AppThemeV2.success : AppThemeV2.danger,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
