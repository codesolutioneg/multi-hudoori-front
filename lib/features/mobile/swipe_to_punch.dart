import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_ui.dart';

/// "Swipe to Check In" slider. Drags toward the reading direction's end
/// (right in LTR, left in RTL) and fires [onCompleted] once past 85%.
class SwipeToPunch extends StatefulWidget {
  const SwipeToPunch({
    super.key,
    required this.label,
    required this.onCompleted,
    this.busy = false,
    this.busyLabel,
    this.enabled = true,
    this.checkOut = false,
  });

  final String label;
  final String? busyLabel;
  final Future<void> Function() onCompleted;
  final bool busy;
  final bool enabled;
  final bool checkOut;

  @override
  State<SwipeToPunch> createState() => _SwipeToPunchState();
}

class _SwipeToPunchState extends State<SwipeToPunch>
    with SingleTickerProviderStateMixin {
  static const _height = 62.0;
  static const _knob = 50.0;
  static const _pad = 6.0;

  double _progress = 0;
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addListener(() => setState(() => _progress = _settleAnim.value));
  late Animation<double> _settleAnim = const AlwaysStoppedAnimation(0);

  @override
  void didUpdateWidget(covariant SwipeToPunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy && !widget.busy) _animateTo(0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _settleAnim = Tween(begin: _progress, end: target).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    _settle.forward(from: 0);
  }

  bool get _interactive => widget.enabled && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final base = widget.checkOut
        ? const LinearGradient(colors: [Color(0xFFFF8A4C), Color(0xFFF2552C)])
        : MobileUi.primaryGradient;

    return LayoutBuilder(
      builder: (context, c) {
        final track = c.maxWidth - _knob - _pad * 2;
        final offset = track * _progress;

        return Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              gradient: base,
              borderRadius: BorderRadius.circular(_height / 2),
              boxShadow: [
                BoxShadow(
                  color: (widget.checkOut
                          ? const Color(0xFFF2552C)
                          : MobileUi.primary)
                      .withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _knob + 16),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: (1 - _progress * 1.6).clamp(0.0, 1.0),
                    child: _Shimmer(
                      enabled: _interactive,
                      child: Text(
                        widget.busy
                            ? (widget.busyLabel ?? widget.label)
                            : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MobileUi.text(
                          15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: _pad + offset,
                  top: _pad,
                  child: GestureDetector(
                    onHorizontalDragUpdate: !_interactive
                        ? null
                        : (d) {
                            final dx = rtl ? -d.delta.dx : d.delta.dx;
                            setState(() {
                              _progress =
                                  (_progress + dx / track).clamp(0.0, 1.0);
                            });
                          },
                    onHorizontalDragEnd: !_interactive
                        ? null
                        : (_) async {
                            if (_progress >= 0.85) {
                              _animateTo(1);
                              HapticFeedback.mediumImpact();
                              await widget.onCompleted();
                              if (mounted && !widget.busy) _animateTo(0);
                            } else {
                              _animateTo(0);
                            }
                          },
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: widget.busy
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: widget.checkOut
                                    ? const Color(0xFFF2552C)
                                    : MobileUi.primary,
                              ),
                            )
                          : Icon(
                              widget.checkOut
                                  ? Icons.logout_rounded
                                  : Icons.arrow_forward_rounded,
                              textDirection: Directionality.of(context),
                              color: widget.checkOut
                                  ? const Color(0xFFF2552C)
                                  : MobileUi.primary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sweeping highlight over the hint text, hinting that the bar is draggable.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = rtl ? 1 - _c.value : _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.65),
              Colors.white,
              Colors.white.withValues(alpha: 0.65),
            ],
            stops: [
              (v - 0.25).clamp(0.0, 1.0),
              v,
              (v + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}
