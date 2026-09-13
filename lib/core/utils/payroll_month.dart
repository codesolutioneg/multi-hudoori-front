/// Payroll cycle helper — matches backend `payrollMonthRange`.
/// Start day 26 means 26 Jan → 25 Feb is one period.
({DateTime dateFrom, DateTime dateTo}) payrollMonthRange(
  DateTime reference,
  int monthStartDay,
) {
  final requestedDay = monthStartDay.clamp(1, 31);
  final ref = DateTime.utc(reference.year, reference.month, reference.day);

  DateTime startOfMonth(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = requestedDay > lastDay ? lastDay : requestedDay;
    return DateTime.utc(year, month, day);
  }

  final thisMonthStart = startOfMonth(ref.year, ref.month);
  final start = !ref.isBefore(thisMonthStart)
      ? thisMonthStart
      : startOfMonth(ref.year, ref.month - 1);
  final nextStart = startOfMonth(start.year, start.month + 1);
  final end = nextStart.subtract(const Duration(days: 1));
  return (dateFrom: start, dateTo: end);
}

String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.length < 10) return null;
  return DateTime.tryParse(text.substring(0, 10));
}
