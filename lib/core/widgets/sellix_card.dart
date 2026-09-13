import 'package:flutter/material.dart';

import '../theme/app_theme_v2.dart';
import '../theme/app_dimensions.dart';

/// Lovable DataCard — aligned with dashboard v2 glass cards.
class SellixCard extends StatefulWidget {
  const SellixCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.spaceMd),
    this.hover = false,
    this.muted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hover;
  final bool muted;
  final VoidCallback? onTap;

  @override
  State<SellixCard> createState() => _SellixCardState();
}

class _SellixCardState extends State<SellixCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final elevated = widget.hover && _hovering;
    final card = AnimatedContainer(
      duration: AppThemeV2.normal,
      curve: Curves.easeOutQuart,
      padding: widget.padding,
      transform: elevated ? (Matrix4.identity()..scale(1.005)) : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.muted ? AppThemeV2.surfaceElevated : AppThemeV2.surface,
        borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
        border: Border.all(
          color: elevated
              ? AppThemeV2.primary.withValues(alpha: 0.25)
              : AppThemeV2.border,
        ),
        boxShadow: elevated ? AppThemeV2.glowShadow : AppThemeV2.cardShadow,
      ),
      child: widget.child,
    );

    Widget result = card;
    if (widget.onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
          child: card,
        ),
      );
    }

    if (!widget.hover) return result;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: result,
    );
  }
}
