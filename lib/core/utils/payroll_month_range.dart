/// Shared payroll period helpers (matches backend `payrollMonthRange`).
library;

export 'payroll_month.dart';

import 'payroll_month.dart';

const int kDefaultPayrollMonthStartDay = 26;

int payrollMonthStartDayFromConfig(Map<String, dynamic>? config) {
  final raw = (config?['payrollMonthStartDay'] as num?)?.toInt();
  if (raw == null) return kDefaultPayrollMonthStartDay;
  return raw.clamp(1, 31);
}

DateTime payrollReferenceUtc([DateTime? reference]) {
  final ref = reference ?? DateTime.now();
  return DateTime.utc(ref.year, ref.month, ref.day);
}

({DateTime dateFrom, DateTime dateTo}) defaultPayrollPeriod(
  int monthStartDay, [
  DateTime? reference,
]) {
  return payrollMonthRange(
    payrollReferenceUtc(reference),
    monthStartDay,
  );
}
