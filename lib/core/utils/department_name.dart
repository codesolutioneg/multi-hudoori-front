import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

String departmentDisplayName(
  Map<String, dynamic> department, {
  required bool isArabic,
}) {
  final ar = department['name']?.toString() ?? department['nameAr']?.toString() ?? '';
  final en = department['nameEn']?.toString() ?? '';
  if (!isArabic && en.isNotEmpty) return en;
  return ar;
}

String employeeDepartmentName(Map<String, dynamic> employee, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (!l10n.isAr) {
    final en = employee['departmentEn']?.toString() ?? '';
    if (en.isNotEmpty) return en;
  }
  return employee['department']?.toString() ?? '';
}
