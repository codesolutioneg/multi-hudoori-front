import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme_v2.dart';

class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppThemeV2.cardPadding),
    this.onTap,
    this.hoverScale = 1.005,
    this.animated = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double hoverScale;
  final bool animated;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final card = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppThemeV2.normal,
          curve: Curves.easeOutQuart,
          transform: Matrix4.identity()
            ..scale(_isHovered ? widget.hoverScale : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppThemeV2.surface,
            borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
            border: Border.all(
              color: _isHovered
                  ? AppThemeV2.primary.withValues(alpha: 0.25)
                  : AppThemeV2.border,
              width: 1,
            ),
            boxShadow: _isHovered ? AppThemeV2.glowShadow : AppThemeV2.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (!widget.animated) return card;

    return card
        .animate()
        .fadeIn(duration: AppThemeV2.slow)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppThemeV2.slow,
          curve: Curves.easeOutQuart,
        );
  }
}
