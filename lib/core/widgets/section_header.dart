import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../theme/app_theme_v2.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppThemeV2.title),
              if (subtitle != null) ...[
                const Gap(4),
                Text(subtitle!, style: AppThemeV2.caption),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
