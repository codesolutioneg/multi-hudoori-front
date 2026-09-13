/// Egyptian 14-digit national ID — century digit + YYMMDD birth date.
import 'package:flutter/widgets.dart';

import '../../l10n/l10n_extension.dart';

class EgyptianNationalIdInfo {
  const EgyptianNationalIdInfo({
    required this.valid,
    required this.nationalId,
    this.birthDate,
    this.age,
    this.errorKey,
  });

  final bool valid;
  final String nationalId;
  final DateTime? birthDate;
  final int? age;

  /// Translation key, so the caller renders it in the viewer's language.
  final String? errorKey;
}

EgyptianNationalIdInfo parseEgyptianNationalId(String raw) {
  final nationalId = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (nationalId.isEmpty) {
    return const EgyptianNationalIdInfo(valid: true, nationalId: '');
  }

  if (!RegExp(r'^\d{14}$').hasMatch(nationalId)) {
    return EgyptianNationalIdInfo(
      valid: false,
      nationalId: nationalId,
      errorKey: 'val.nidLength',
    );
  }

  final centuryDigit = nationalId[0];
  if (centuryDigit != '2' && centuryDigit != '3') {
    return EgyptianNationalIdInfo(
      valid: false,
      nationalId: nationalId,
      errorKey: 'val.nidCentury',
    );
  }

  final yy = int.parse(nationalId.substring(1, 3));
  final mm = int.parse(nationalId.substring(3, 5));
  final dd = int.parse(nationalId.substring(5, 7));
  final year = (centuryDigit == '2' ? 1900 : 2000) + yy;
  final birthDate = DateTime(year, mm, dd);

  if (birthDate.year != year || birthDate.month != mm || birthDate.day != dd) {
    return EgyptianNationalIdInfo(
      valid: false,
      nationalId: nationalId,
      errorKey: 'val.nidBirthInvalid',
    );
  }

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  if (birthDate.isAfter(todayDate)) {
    return EgyptianNationalIdInfo(
      valid: false,
      nationalId: nationalId,
      errorKey: 'val.nidBirthFuture',
    );
  }

  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }

  return EgyptianNationalIdInfo(
    valid: true,
    nationalId: nationalId,
    birthDate: birthDate,
    age: age >= 0 ? age : null,
  );
}

String? validateEgyptianNationalId(BuildContext context, String raw) {
  final info = parseEgyptianNationalId(raw);
  return info.valid || info.errorKey == null ? null : context.t(info.errorKey!);
}

String formatBirthDateIso(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
