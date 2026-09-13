import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final displaySubtitle = subtitle ?? context.t('placeholder.underDevelopment');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(title: title, subtitle: displaySubtitle, icon: Icons.apps_outlined),
          const SizedBox(height: 24),
          SellixCard(
            child: Column(
              children: [
                Icon(Icons.construction, size: 48, color: AppColors.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text(displaySubtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
