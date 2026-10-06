import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import 'mobile_ui.dart';

/// Native-mobile page header: icon + title on one line, icon-only tools on
/// the end, and labelled actions in a single horizontally scrolling strip
/// (primary/filled actions first) instead of wrapping into several rows.
class MobilePageHeader extends StatelessWidget {
  const MobilePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onBack;
  final List<Widget> actions;

  static bool _isTool(Widget w) => w is IconButton || w is PopupMenuButton;

  static bool _isPrimary(Widget w) => w is FilledButton || w is ElevatedButton;

  @override
  Widget build(BuildContext context) {
    final tools = actions.where(_isTool).toList();
    final labelled = [
      ...actions.where((w) => !_isTool(w) && _isPrimary(w)),
      ...actions.where((w) => !_isTool(w) && !_isPrimary(w)),
    ];

    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final textStyle = MobileUi.text(13, weight: FontWeight.w700, height: 1.2);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                _CircleTool(
                  icon: Icons.arrow_back_rounded,
                  tooltip: context.t('common.back'),
                  onTap: onBack,
                ),
                const SizedBox(width: 10),
              ],
              if (icon != null) ...[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: MobileUi.primaryGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: MobileUi.primary.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(21, weight: FontWeight.w800, height: 1.25),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MobileUi.text(12.5, weight: FontWeight.w500, color: MobileUi.muted, height: 1.35),
                      ),
                  ],
                ),
              ),
              if (tools.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(
                    iconButtonTheme: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: MobileUi.ink,
                        fixedSize: const Size(42, 42),
                        minimumSize: const Size(42, 42),
                        iconSize: 21,
                        side: const BorderSide(color: Color(0xFFE6EBF3)),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in tools) ...[
                        const SizedBox(width: 6),
                        t,
                      ],
                    ],
                  ),
                ),
            ],
          ),
          if (labelled.isNotEmpty) ...[
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: MobileUi.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: pill,
                    textStyle: textStyle,
                    elevation: 0,
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MobileUi.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: pill,
                    textStyle: textStyle,
                    elevation: 0,
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: MobileUi.ink,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: const BorderSide(color: Color(0xFFE6EBF3)),
                    shape: pill,
                    textStyle: textStyle,
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: pill,
                    textStyle: textStyle,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (var i = 0; i < labelled.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      labelled[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleTool extends StatelessWidget {
  const _CircleTool({required this.icon, this.tooltip, this.onTap});

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFE6EBF3))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 21, color: MobileUi.ink),
          ),
        ),
      ),
    );
  }
}
