import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/feature_entitlements.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';

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
    final isWebOnly = reason == 'web_only';
    final featureName = featureLabel(featureKey, isAr: isAr);

    final title = isWebOnly
        ? context.t('errors.webOnlyTitle')
        : isFeature
            ? context.t('errors.featureDisabledTitle')
            : context.t('errors.accessDeniedTitle');
    final message = isWebOnly
        ? context.t('errors.webOnlyBody')
        : isFeature
            ? context.t('errors.featureDisabledNamed', {'feature': featureName})
            : context.t('errors.accessDeniedPage');
    final hint = isWebOnly
        ? context.t('errors.webOnlyHint')
        : isFeature
            ? context.t('errors.featureDisabledHint')
            : context.t('errors.accessDeniedHint');

    return AppPageScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWebOnly
                    ? Icons.computer_outlined
                    : isFeature
                        ? Icons.lock_outline_rounded
                        : Icons.block,
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
                hint,
                style: AppThemeV2.caption,
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              if (isWebOnly)
                FilledButton.icon(
                  onPressed: () async {
                    await context.read<AuthCubit>().signOut();
                    if (context.mounted) context.go(AppRoutes.signIn);
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(context.l10n.logout),
                  style: FilledButton.styleFrom(backgroundColor: AppThemeV2.primary),
                )
              else
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
