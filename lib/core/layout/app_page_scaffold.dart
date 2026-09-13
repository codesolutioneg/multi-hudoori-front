import 'package:flutter/material.dart';
import '../../l10n/l10n_extension.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme_v2.dart';

/// Standard page wrapper — centered max width with dashboard spacing.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
    this.maxWidth = 1360,
  });

  final Widget child;
  final bool scrollable;
  /// When null, uses responsive padding (tighter on mobile).
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  EdgeInsetsGeometry _padding(BuildContext context) {
    if (padding != null) return padding!;
    final mobile = isMobile(context);
    return EdgeInsets.fromLTRB(
      mobile ? 12 : 24,
      mobile ? 12 : 20,
      mobile ? 12 : 24,
      mobile ? 20 : 32,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = _padding(context);
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (!scrollable) {
      // Fill shell height so Column + Expanded children (lists/empty states) work.
      return Padding(
        padding: pad,
        child: SizedBox.expand(child: content),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: pad,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              // Allow empty states / short pages to use remaining viewport height.
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight -
                        (pad is EdgeInsets
                            ? pad.vertical
                            : pad.resolve(Directionality.of(context)).vertical))
                      .clamp(0.0, double.infinity)
                  : 0,
            ),
            child: content,
          ),
        );
      },
    );
  }
}

/// Compact page header row inside a glass card (dashboard v2 style).
class AppPageHeaderV2 extends StatelessWidget {
  const AppPageHeaderV2({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile(context) ? 14 : 20,
        vertical: isMobile(context) ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: AppThemeV2.surface,
        borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
        border: Border.all(color: AppThemeV2.border),
        boxShadow: AppThemeV2.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 720;
          final leading = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.t('common.back'),
                  style: IconButton.styleFrom(
                    backgroundColor: AppThemeV2.surfaceElevated,
                    foregroundColor: AppThemeV2.textSecondary,
                  ),
                ),
              if (icon != null) ...[
                if (onBack != null) const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppThemeV2.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ],
            ],
          );

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppThemeV2.headline.copyWith(fontSize: 22)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppThemeV2.caption),
              ],
            ],
          );

          final actionWrap = actions == null || actions!.isEmpty
              ? const SizedBox.shrink()
              : Wrap(spacing: 8, runSpacing: 8, children: actions!);

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                  ],
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  actionWrap,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              if (onBack != null || icon != null) const SizedBox(width: 12),
              Expanded(child: titleBlock),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 12),
                actionWrap,
              ],
            ],
          );
        },
      ),
    );
  }
}
