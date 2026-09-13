import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_theme_v2.dart';
import '../utils/app_log.dart';
import 'v2_checkbox.dart';

/// Config row with a v2 checkbox and saving state — web-safe.
class AsyncCheckboxTile extends StatelessWidget {
  const AsyncCheckboxTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.loading = false,
    this.disabled = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool loading;
  final bool disabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final canChange = !loading && !disabled && onChanged != null;

    void toggle() {
      if (!canChange) return;
      appLog('AsyncCheckboxTile', 'tap', {'title': title, 'from': value, 'to': !value});
      onChanged!(!value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: value
              ? AppThemeV2.primarySoft.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: canChange ? toggle : null,
            borderRadius: BorderRadius.circular(12),
            hoverColor: AppThemeV2.primarySoft.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  V2Checkbox(
                    value: value,
                    loading: loading,
                    // Row handles taps — avoid double-toggle on web.
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppThemeV2.title.copyWith(fontSize: 14),
                        ),
                        if (subtitle != null) ...[
                          const Gap(4),
                          Text(subtitle!, style: AppThemeV2.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppThemeV2.normal,
          curve: Curves.easeOut,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppThemeV2.primary,
                    backgroundColor: AppThemeV2.primarySoft,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
