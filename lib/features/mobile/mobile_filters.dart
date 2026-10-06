import 'package:flutter/material.dart';

import '../../core/platform/mobile_platform.dart';
import '../../l10n/l10n_extension.dart';
import 'mobile_ui.dart';

/// Collapsed-by-default filter section for native mobile so list screens
/// open on their data instead of a wall of dropdowns. Returns [child]
/// unchanged on web.
class MobileFilters extends StatefulWidget {
  const MobileFilters({
    super.key,
    required this.child,
    this.activeCount = 0,
    this.title,
    this.leading,
  });

  final Widget child;

  /// Number of non-default filters, shown as a badge while collapsed.
  final int activeCount;
  final String? title;

  /// Always-visible control (usually the search field) above the toggle.
  final Widget? leading;

  @override
  State<MobileFilters> createState() => _MobileFiltersState();
}

class _MobileFiltersState extends State<MobileFilters> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!isNativeMobile) {
      if (widget.leading == null) return widget.child;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [widget.leading!, const SizedBox(height: 12), widget.child],
      );
    }

    final active = widget.activeCount > 0;
    final toggle = Material(
      color: _open || active ? MobileUi.primarySoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _open || active
              ? MobileUi.primary.withValues(alpha: 0.25)
              : const Color(0xFFE6EBF3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _open = !_open),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: widget.leading == null ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _open || active ? MobileUi.primary : MobileUi.ink,
                ),
                if (widget.leading == null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title ?? context.t('m.filters'),
                      style: MobileUi.text(14, weight: FontWeight.w700, height: 1.2),
                    ),
                  ),
                ],
                if (active) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: MobileUi.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.activeCount}',
                      textAlign: TextAlign.center,
                      style: MobileUi.text(11.5, weight: FontWeight.w800, color: Colors.white, height: 1.4),
                    ),
                  ),
                ],
                if (widget.leading == null) ...[
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: MobileUi.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.leading != null)
          Row(
            children: [
              Expanded(child: widget.leading!),
              const SizedBox(width: 8),
              toggle,
            ],
          )
        else
          toggle,
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
