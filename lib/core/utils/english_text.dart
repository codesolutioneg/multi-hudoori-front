/// Hiring form text fields must be English/Latin only (no Arabic).
import 'package:flutter/widgets.dart';

import '../../l10n/l10n_extension.dart';

final _englishTextPattern = RegExp(r"^[A-Za-z0-9\s.,'\-/&()]+$");
final _englishCodePattern = RegExp(r'^[A-Za-z0-9_-]+$');

/// Name / job title: Latin letters, digits, and common punctuation.
String? validateEnglishText(
  BuildContext context,
  String? raw, {
  required String fieldLabel,
  int minLength = 1,
}) {
  final value = raw?.trim() ?? '';
  if (value.length < minLength) {
    return context.t('val.required', {'field': fieldLabel});
  }
  if (!_englishTextPattern.hasMatch(value)) {
    return context.t('val.englishOnly', {'field': fieldLabel});
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
    return context.t('val.needsEnglishLetters', {'field': fieldLabel});
  }
  return null;
}

/// Fingerprint / emp code: English letters, digits, underscore, hyphen.
String? validateEnglishCode(BuildContext context, String? raw, {String? fieldLabel}) {
  final label = fieldLabel ?? context.t('val.fingerprintCode');
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return context.t('val.required', {'field': label});
  if (!_englishCodePattern.hasMatch(value)) {
    return context.t('val.englishCodeOnly', {'field': label});
  }
  return null;
}
