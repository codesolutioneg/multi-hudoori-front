import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_v2.dart';

/// Subtle web-native page backdrop — no image assets, pure Dart painting.
class DashboardPageBackground extends StatelessWidget {
  const DashboardPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF1F5F9),
                AppThemeV2.background,
                AppThemeV2.background,
              ],
              stops: [0.0, 0.22, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter()),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppThemeV2.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.45), paint);
    }
    for (var y = 0.0; y < size.height * 0.45; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
