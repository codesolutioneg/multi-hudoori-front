import 'package:flutter/material.dart';

import '../../core/platform/mobile_platform.dart';
import '../../l10n/app_localizations.dart';
import 'mobile_ui.dart';

/// Horizontal scroller for wide tables. On native mobile it adds a swipe hint,
/// an always-visible scrollbar and compact [DataTable] styling; elsewhere it is
/// a plain horizontal [SingleChildScrollView].
class MobileHScroll extends StatefulWidget {
  const MobileHScroll({super.key, required this.child, this.showHint = true});

  final Widget child;
  final bool showHint;

  @override
  State<MobileHScroll> createState() => _MobileHScrollState();
}

class _MobileHScrollState extends State<MobileHScroll> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isNativeMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: widget.child,
      );
    }
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                const Icon(Icons.swipe_rounded, size: 17, color: MobileUi.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('m.scrollHint'),
                    style: MobileUi.text(11.5, weight: FontWeight.w600, color: MobileUi.muted),
                  ),
                ),
              ],
            ),
          ),
        Scrollbar(
          controller: _ctrl,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 5,
          radius: const Radius.circular(8),
          child: SingleChildScrollView(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 12),
            child: DataTableTheme(
              data: DataTableThemeData(
                columnSpacing: 20,
                horizontalMargin: 12,
                headingRowHeight: 44,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 56,
                headingRowColor: const WidgetStatePropertyAll(MobileUi.primarySoft),
                headingTextStyle: MobileUi.text(12.5, weight: FontWeight.w800, color: MobileUi.primaryDeep),
                dataTextStyle: MobileUi.text(12.5, weight: FontWeight.w600),
                dividerThickness: 0.6,
              ),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
