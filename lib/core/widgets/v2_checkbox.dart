import 'package:flutter/material.dart';

import '../theme/app_theme_v2.dart';

/// Visual checkbox indicator — parent row handles taps (avoids double-toggle on web).
class V2Checkbox extends StatelessWidget {
  const V2Checkbox({
    super.key,
    required this.value,
    this.loading = false,
    this.size = 26,
  });

  final bool value;
  final bool loading;
  final double size;

  @override
  Widget build(BuildContext context) {
    final checked = value && !loading;

    return Semantics(
      checked: value,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: AppThemeV2.normal,
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: checked ? AppThemeV2.primaryGradient : null,
            color: checked ? null : AppThemeV2.surface,
            border: Border.all(
              color: checked ? Colors.transparent : AppThemeV2.border,
              width: 1.5,
            ),
            boxShadow: checked
                ? [
                    BoxShadow(
                      color: AppThemeV2.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: loading
              ? Padding(
                  padding: EdgeInsets.all(size * 0.2),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppThemeV2.primary,
                  ),
                )
              : checked
                  ? Icon(Icons.check_rounded, size: size * 0.68, color: Colors.white)
                  : null,
        ),
      ),
    );
  }
}
