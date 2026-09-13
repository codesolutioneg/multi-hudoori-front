import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/status_tag.dart';

/// Collapsible settings panel with icon, title, and animated body.
class SettingsAccordionSection extends StatefulWidget {
  const SettingsAccordionSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.badgeType,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpansionChanged,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final String? badge;
  final Color? badgeColor;
  final StatusTagType? badgeType;
  final bool initiallyExpanded;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<SettingsAccordionSection> createState() => _SettingsAccordionSectionState();
}

class _SettingsAccordionSectionState extends State<SettingsAccordionSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _iconTurn;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded ?? widget.initiallyExpanded;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _iconTurn = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (_expanded) _controller.value = 1;
  }

  @override
  void didUpdateWidget(SettingsAccordionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null && widget.expanded != _expanded) {
      _setExpanded(widget.expanded!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setExpanded(bool value) {
    setState(() => _expanded = value);
    if (value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onExpansionChanged?.call(value);
  }

  void _toggle() => _setExpanded(!_expanded);

  StatusTagType _badgeType() {
    if (widget.badgeType != null) return widget.badgeType!;
    final c = widget.badgeColor;
    if (c == AppColors.success) return StatusTagType.success;
    if (c == AppColors.danger) return StatusTagType.danger;
    if (c == AppColors.warning) return StatusTagType.warning;
    return StatusTagType.info;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
        boxShadow: _expanded ? AppShadows.elevated : AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: _expanded ? AppColors.primarySoft.withValues(alpha: 0.5) : Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _expanded ? AppColors.primary : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 22,
                        color: _expanded ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppThemeV2.cardTitle(
                              color: _expanded ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              style: AppThemeV2.cardSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.badge != null) ...[
                      const SizedBox(width: 8),
                      StatusTag(label: widget.badge!, type: _badgeType(), dot: true),
                    ],
                    RotationTransition(
                      turns: _iconTurn,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _expanded ? AppColors.primary : AppColors.textMuted,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  child: widget.child,
                ),
              ],
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}
