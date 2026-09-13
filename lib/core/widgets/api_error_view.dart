import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme_v2.dart';
import '../utils/api_error_message.dart';
import '../../l10n/l10n_extension.dart';

/// Full-page friendly error with retry — hides technical exception text from users.
class ApiErrorView extends StatelessWidget {
  const ApiErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = friendlyApiError(context, error);
    final title = context.t('errors.title');

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: compact ? 40 : 56,
                color: AppColors.textMuted,
              ),
              Gap(compact ? 12 : 16),
              Text(
                title,
                style: AppThemeV2.title.copyWith(fontSize: compact ? 16 : 18),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              Text(
                message,
                style: AppThemeV2.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              Gap(compact ? 16 : 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.t('common.retry')),
                style: FilledButton.styleFrom(backgroundColor: AppThemeV2.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
