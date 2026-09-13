import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'sellix_card.dart';

enum StatCardTone { primary, success, warning, info, danger }

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.tone = StatCardTone.primary,
    this.hint,
  });

  final String title;
  final String value;
  final IconData icon;
  final StatCardTone tone;
  final String? hint;

  (Color bg, Color fg) get _colors => switch (tone) {
        StatCardTone.success => (AppColors.success.withValues(alpha: 0.1), AppColors.success),
        StatCardTone.warning => (AppColors.warning.withValues(alpha: 0.15), AppColors.warningForeground),
        StatCardTone.info => (AppColors.info.withValues(alpha: 0.1), AppColors.info),
        StatCardTone.danger => (AppColors.danger.withValues(alpha: 0.1), AppColors.danger),
        StatCardTone.primary => (AppColors.primarySoft, AppColors.primary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return SellixCard(
      hover: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(hint!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
