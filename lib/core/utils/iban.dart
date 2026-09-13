import 'package:flutter/widgets.dart';

import '../../l10n/l10n_extension.dart';

String normalizeEgyptianIban(String value) =>
    value.replaceAll(RegExp(r'\s'), '').toUpperCase();

String? validateEgyptianIban(
  BuildContext context,
  String value, {
  required bool required,
}) {
  final iban = normalizeEgyptianIban(value);
  if (iban.isEmpty) {
    return required ? context.t('val.ibanRequired') : null;
  }
  if (!RegExp(r'^EG\d{27}$').hasMatch(iban)) {
    return context.t('val.ibanInvalid');
  }
  return null;
}

String? validateEgyptianMobileLine(
  BuildContext context,
  String value, {
  required bool required,
}) {
  final phone = value.replaceAll(RegExp(r'\s'), '');
  if (phone.isEmpty) {
    return required ? context.t('val.mobileRequired') : null;
  }
  if (!RegExp(r'^01[0125]\d{8}$').hasMatch(phone)) {
    return context.t('val.mobileInvalid');
  }
  return null;
}
