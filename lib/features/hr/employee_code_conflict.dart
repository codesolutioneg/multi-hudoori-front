import 'package:flutter/material.dart';

import '../../data/api/biotime_api_client.dart';
import '../../l10n/l10n_extension.dart';

bool isArchivedCodeConflict(Object error) =>
    error is BioTimeApiException && error.code == 'CODE_ARCHIVED_CONFLICT';

bool isActiveCodeDuplicate(Object error) =>
    error is BioTimeApiException &&
    error.code == 'DUPLICATE' &&
    !((error.message).contains('قومي') ||
        (error.message.toLowerCase().contains('national')));

String archivedConflictCode(Object error, {String fallback = ''}) {
  if (error is! BioTimeApiException) return fallback;
  final fromData = error.data['code']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) return fromData;
  return fallback;
}

String? archivedConflictName(Object error) {
  if (error is! BioTimeApiException) return null;
  final name = error.data['conflictName']?.toString().trim();
  if (name == null || name.isEmpty) return null;
  return name;
}

/// Returns true when the user agrees to delete the archived holder and continue.
Future<bool> confirmTakeArchivedEmployeeCode(
  BuildContext context, {
  required String code,
  String? conflictName,
}) async {
  final namePart =
      (conflictName != null && conflictName.trim().isNotEmpty)
          ? ' ($conflictName)'
          : '';
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: Text(context.t('emp.codeArchivedConflictTitle')),
      content: Text(
        context.t('emp.codeArchivedConflictBody', {
          'code': code,
          'name': namePart,
        }),
        style: const TextStyle(height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.t('emp.codeArchivedConflictReject')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.t('emp.codeArchivedConflictContinue')),
        ),
      ],
    ),
  );
  return ok == true;
}
