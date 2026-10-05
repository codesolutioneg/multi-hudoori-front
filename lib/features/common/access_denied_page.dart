import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/feature_entitlements.dart';
import '../../l10n/l10n_extension.dart';

/// Clear full-page message when a route is blocked by role or plan entitlement.
class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({
    super.key,
    this.reason,
    this.featureKey,
  });

  final String? reason;
  final String? featureKey;

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.isAr;
    final isFeature = reason == 'feature';
    final featureName = featureLabel(featureKey, isAr: isAr);
    final title = isFeature
        ? context.t('errors.featureDisabledTitle')
        : context.t('errors.accessDeniedTitle');
    final message = isFeature
        ? context.t('errors.featureDisabledNamed', {'feature': featureName})
        : context.t('errors.accessDeniedPage');

    return AppPageScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFeature ? Icons.lock_outline_rounded : Icons.block,
                size: 56,
                color: AppThemeV2.warning,
              ),
              const Gap(16),
              Text(
                title,
                style: AppThemeV2.title.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const Gap(10),
              Text(
                message,
                style: AppThemeV2.body.copyWith(color: AppThemeV2.textMuted),
                textAlign: TextAlign.center,
              ),
              const Gap(12),
              Text(
                isFeature
                    ? context.t('errors.featureDisabledHint')
                    : context.t('errors.accessDeniedHint'),
                style: AppThemeV2.caption,
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.dashboard),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: Text(context.t('errors.backHome')),
                style: FilledButton.styleFrom(backgroundColor: AppThemeV2.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
