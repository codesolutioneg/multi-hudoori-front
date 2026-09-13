import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

enum AlertBannerTone { info, warning, error, success }

class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.message,
    this.tone = AlertBannerTone.info,
    this.child,
  });

  final String message;
  final AlertBannerTone tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      AlertBannerTone.warning => (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warningForeground,
          Icons.warning_amber_rounded,
        ),
      AlertBannerTone.error => (
          AppColors.danger.withValues(alpha: 0.1),
          AppColors.danger,
          Icons.error_outline_rounded,
        ),
      AlertBannerTone.success => (
          AppColors.success.withValues(alpha: 0.1),
          AppColors.success,
          Icons.check_circle_outline_rounded,
        ),
      AlertBannerTone.info => (
          AppColors.info.withValues(alpha: 0.1),
          AppColors.info,
          Icons.info_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(color: fg, fontSize: 13, height: 1.45),
              child: child ?? Text(message),
            ),
          ),
        ],
      ),
    );
  }
}
