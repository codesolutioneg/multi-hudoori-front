import 'package:flutter/material.dart';
import '../../l10n/l10n_extension.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'sellix_card.dart';

/// Explains that this HR screen is managed locally, not imported from BioTime sync.
class HrLocalDataBanner extends StatelessWidget {
  const HrLocalDataBanner({
    super.key,
    required this.title,
    this.hint,
  });

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  hint ??
                      context.t('hrLocal.notImported'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HrEmptyListCard extends StatelessWidget {
  const HrEmptyListCard({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final inner = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 44,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final canStretch =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        return SizedBox(
          width: double.infinity,
          height: canStretch ? constraints.maxHeight : null,
          child: SellixCard(
            child: canStretch
                ? inner
                : ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 280),
                    child: inner,
                  ),
          ),
        );
      },
    );
  }
}
