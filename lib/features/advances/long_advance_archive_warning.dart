import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../l10n/l10n_extension.dart';

Map<String, dynamic>? longAdvanceWarningMap(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final count = m['count'];
  if (count is! num || count <= 0) return null;
  return m;
}

Widget? buildLongAdvanceArchiveWarningBanner(
  BuildContext context,
  dynamic warningRaw, {
  String messageKey = 'employees.archive.longAdvanceWarning',
}) {
  final w = longAdvanceWarningMap(warningRaw);
  if (w == null) return null;
  final text = messageKey == 'employees.archive.longAdvanceWarning'
      ? context.t(messageKey, {
          'count': '${w['count'] ?? 0}',
          'remaining': formatMoney(w['remainingAmount']),
          'installments': '${w['remainingInstallments'] ?? 0}',
        })
      : context.t(messageKey, {
          'name': w['employeeName']?.toString() ?? '',
          'code': w['employeeCode']?.toString() ?? '',
          'remaining': formatMoney(w['remainingAmount']),
          'installments': '${w['remainingInstallments'] ?? 0}',
        });
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(height: 1.4, fontSize: 13)),
        ),
      ],
    ),
  );
}

String longAdvanceArchiveSnackMessage(BuildContext context, Map<String, dynamic> w) {
  return context.t('grid.longAdvanceArchiveWarning', {
    'name': w['employeeName']?.toString() ?? '',
    'code': w['employeeCode']?.toString() ?? '',
    'remaining': formatMoney(w['remainingAmount']),
    'installments': '${w['remainingInstallments'] ?? 0}',
  });
}

void showLongAdvanceWarningsFromResponse(
  BuildContext context,
  void Function(String message) snack, {
  required Map<String, dynamic> response,
}) {
  final single = longAdvanceWarningMap(response['longAdvanceWarning']);
  if (single != null) {
    snack(longAdvanceArchiveSnackMessage(context, single));
  }
  final list = response['longAdvanceArchiveWarnings'];
  if (list is List) {
    for (final item in list) {
      final w = longAdvanceWarningMap(item);
      if (w != null) snack(longAdvanceArchiveSnackMessage(context, w));
    }
  }
}
