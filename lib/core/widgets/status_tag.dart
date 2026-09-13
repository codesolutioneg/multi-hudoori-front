import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum StatusTagType { success, warning, danger, info, neutral }

class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.label,
    this.type = StatusTagType.neutral,
    this.dot = false,
  });

  final String label;
  final StatusTagType type;
  final bool dot;

  Color get _color => switch (type) {
        StatusTagType.success => AppColors.success,
        StatusTagType.warning => AppColors.warningForeground,
        StatusTagType.danger => AppColors.danger,
        StatusTagType.info => AppColors.info,
        StatusTagType.neutral => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
