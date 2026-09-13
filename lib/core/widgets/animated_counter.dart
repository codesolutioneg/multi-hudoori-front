import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme_v2.dart';

class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Text(
      value.toString(),
      style: style ?? AppThemeV2.statValue,
    )
        .animate()
        .fadeIn(duration: duration)
        .scaleXY(
          begin: 0.8,
          end: 1.0,
          duration: duration,
          curve: Curves.easeOutExpo,
        );
  }
}
