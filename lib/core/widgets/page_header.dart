import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme_v2.dart';

/// Page title block — delegates to v2 glass styling.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
    this.backOnEnd = false,
    this.showRefresh = false,
    this.onRefresh,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  /// When true, places the back button on the end side (left in RTL),
  /// opposite the title — used on employee detail.
  final bool backOnEnd;
  final bool showRefresh;
  final VoidCallback? onRefresh;
  final IconData? icon;

  Widget _backButton(BuildContext context) {
    // When the button sits on the end side, point toward that edge
    // (→ in LTR, ← in RTL). Otherwise use the standard back arrow.
    final iconData = backOnEnd
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;
    return IconButton(
      onPressed: onBack,
      icon: Icon(iconData),
      tooltip: context.t('common.back'),
      style: IconButton.styleFrom(
        backgroundColor: AppThemeV2.surfaceElevated,
        foregroundColor: AppThemeV2.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final actionRow = <Widget>[
      if (actions != null) ...actions!,
      if (showRefresh)
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: AppThemeV2.surfaceElevated,
            foregroundColor: AppThemeV2.textMuted,
          ),
        ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 20,
        vertical: mobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: AppThemeV2.surface,
        borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
        border: Border.all(color: AppThemeV2.border),
        boxShadow: AppThemeV2.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Use available content width (after sidebar), not just window width.
          // Many action buttons on medium widths must stack or they squeeze the
          // title to 0 and make the rest of the page look blank.
          final manyActions = actionRow.length >= 4;
          final compact = mobile ||
              c.maxWidth < 720 ||
              (manyActions && c.maxWidth < 1100);
          final backBtn = onBack == null ? null : _backButton(context);
          final endBack = backOnEnd ? backBtn : null;
          final startBack = backOnEnd ? null : backBtn;

          final titleColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppThemeV2.headline.copyWith(fontSize: compact ? 20 : 24),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppThemeV2.caption),
              ],
            ],
          );

          final leading = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (startBack != null) startBack,
              if (icon != null) ...[
                if (startBack != null) const SizedBox(width: 8),
                Container(
                  width: compact ? 40 : 42,
                  height: compact ? 40 : 42,
                  decoration: BoxDecoration(
                    gradient: AppThemeV2.primaryGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: Colors.white, size: compact ? 18 : 20),
                ),
              ],
            ],
          );

          final hasLeading = startBack != null || icon != null;
          final actionsWrap = actionRow.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.start,
                  children: actionRow,
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLeading) leading,
                    if (hasLeading) const SizedBox(width: 10),
                    Expanded(child: titleColumn),
                    if (endBack != null) ...[
                      const SizedBox(width: 8),
                      endBack,
                    ],
                  ],
                ),
                if (actionRow.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  actionsWrap,
                ],
              ],
            );
          }

          // Keep Wrap inside Flexible so it has a max width and can wrap —
          // a bare Wrap in a Row gets unbounded width and never wraps,
          // squeezing Expanded(title) to zero on medium layouts.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLeading) leading,
                    if (hasLeading) const SizedBox(width: 12),
                    Expanded(child: titleColumn),
                  ],
                ),
              ),
              if (actionRow.isNotEmpty || endBack != null) ...[
                const SizedBox(width: 16),
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        ...actionRow,
                        if (endBack != null) endBack,
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
