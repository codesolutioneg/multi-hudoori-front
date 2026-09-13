import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme_v2.dart';

enum BadgeTone { online, offline, warning, draft, info }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.online,
    this.pulse = false,
  });

  final String label;
  final BadgeTone tone;
  final bool pulse;

  (Color bg, Color fg, Color dot) get _colors => switch (tone) {
        BadgeTone.online => (
            const Color(0xFFD1FAE5), // emerald-100
            AppThemeV2.success,
            AppThemeV2.success,
          ),
        BadgeTone.offline => (
            AppThemeV2.surfaceElevated,
            AppThemeV2.textMuted,
            AppThemeV2.textMuted,
          ),
        BadgeTone.warning => (
            const Color(0xFFFEF3C7), // amber-100
            AppThemeV2.warning,
            AppThemeV2.warning,
          ),
        BadgeTone.draft => (
            const Color(0xFFCFFAFE), // cyan-100
            AppThemeV2.info,
            AppThemeV2.info,
          ),
        BadgeTone.info => (
            AppThemeV2.primarySoft, // blue-100
            AppThemeV2.primary,
            AppThemeV2.primary,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dot) = _colors;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );

    if (pulse) {
      badge = badge
          .animate(onPlay: (controller) => controller.repeat())
          .scaleXY(begin: 1.0, end: 1.05, duration: 1000.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(begin: 1.05, end: 1.0, duration: 1000.ms, curve: Curves.easeInOut);
    }

    return badge;
  }
}
