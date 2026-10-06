import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/platform/mobile_platform.dart';
import 'mobile_ui.dart';

/// Brand loading indicator: the splash's logo card with an orbiting arc,
/// ripples and a fingerprint scan line. Falls back to a compact spinning arc
/// when squeezed (buttons, list footers) and to the stock Material spinner
/// on web.
class HudooriLoader extends StatefulWidget {
  const HudooriLoader({super.key, this.label, this.size = 120});

  final String? label;

  /// Edge of the square the orbit fills when there is room for it.
  final double size;

  @override
  State<HudooriLoader> createState() => _HudooriLoaderState();
}

class _HudooriLoaderState extends State<HudooriLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isNativeMobile) return const CircularProgressIndicator();

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = math.min(constraints.maxWidth, constraints.maxHeight);
        if (room < 72) {
          final s = room.isFinite ? room.clamp(14.0, 40.0) : 28.0;
          return SizedBox.square(
            dimension: s,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(painter: _MiniArcPainter(_c.value)),
            ),
          );
        }

        final size = math.min(widget.size, room);
        final card = size * 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  final breathe = 1 + 0.04 * math.sin(t * math.pi * 2);
                  return CustomPaint(
                    painter: _OrbitPainter(t),
                    child: Center(
                      child: Transform.scale(
                        scale: breathe,
                        child: _Card(size: card, scan: t),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.label != null && widget.label!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: MobileUi.text(13, weight: FontWeight.w600, color: MobileUi.muted),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.size, required this.scan});

  final double size;
  final double scan;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.3;
    final y = size * (0.16 + 0.68 * Curves.easeInOut.transform(scan));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: MobileUi.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            OverflowBox(
              maxWidth: size * 1.36,
              maxHeight: size * 1.36,
              child: HudooriMark(size: size * 1.36),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: y - size * 0.22,
              height: size * 0.22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0),
                      const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: size * 0.14,
              right: size * 0.14,
              top: y - 1,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xCC38BDF8), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2;

    for (var i = 0; i < 2; i++) {
      final p = (t + i / 2) % 1.0;
      canvas.drawCircle(
        c,
        base * (0.42 + 0.5 * Curves.easeOut.transform(p)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = MobileUi.primary.withValues(alpha: 0.22 * (1 - p)),
      );
    }

    final radius = base * 0.82;
    final rect = Rect.fromCircle(center: c, radius: radius);
    final start = t * math.pi * 2;
    const sweep = math.pi * 0.95;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = MobileUi.primary.withValues(alpha: 0.1),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: sweep,
          transform: GradientRotation(start),
          colors: [
            MobileUi.primary.withValues(alpha: 0),
            MobileUi.primary,
          ],
        ).createShader(rect),
    );
    final head = c + Offset(math.cos(start + sweep), math.sin(start + sweep)) * radius;
    canvas.drawCircle(head, 8, Paint()..color = MobileUi.primary.withValues(alpha: 0.18));
    canvas.drawCircle(head, 3.8, Paint()..color = MobileUi.primary);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

class _MiniArcPainter extends CustomPainter {
  _MiniArcPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.shortestSide / 9).clamp(2.0, 3.5);
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final start = t * math.pi * 4;
    final sweep = math.pi * (0.55 + 0.4 * math.sin(t * math.pi * 2).abs());
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = MobileUi.primary.withValues(alpha: 0.14),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = MobileUi.primary,
    );
  }

  @override
  bool shouldRepaint(_MiniArcPainter old) => old.t != t;
}
