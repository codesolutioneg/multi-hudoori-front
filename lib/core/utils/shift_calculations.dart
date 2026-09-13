import '../../l10n/l10n_extension.dart';

/// Odoo biotime.shift time calculations (float hours: 8.5 = 08:30).
class ShiftCalculations {
  ShiftCalculations._();

  static double parseTimeToFloat(String raw, {double fallback = 8}) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return fallback;
    final n = double.tryParse(t);
    if (n != null && n >= 0 && n < 24) return n;
    if (t.contains(':')) {
      final parts = t.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return h + m / 60;
    }
    return fallback;
  }

  static String floatToDisplay(double floatTime) {
    final hours = floatTime.floor();
    final minutes = ((floatTime - hours) * 60).round();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static bool computeIsOvernight(double start, double end) => end < start;

  static double computeTotalHours(double start, double end, {double breakHours = 0}) {
    final overnight = computeIsOvernight(start, end);
    final total = overnight ? (24 - start) + end : end - start;
    final result = total - breakHours;
    return result < 0 ? 0 : (result * 100).roundToDouble() / 100;
  }

  static String? validateTimes(double start, double end) {
    if (start < 0 || start >= 24) return tr('shiftCalc.startRange');
    if (end < 0 || end >= 24) return tr('shiftCalc.endRange');
    if (start == end) return tr('shiftCalc.sameTimes');
    return null;
  }

  static bool isRamadanShift(Map<String, dynamic> shift) {
    final name = shift['name']?.toString().toLowerCase() ?? '';
    final code = shift['code']?.toString().trim().toLowerCase() ?? '';
    return name.contains('رمضان') || name.contains('ramadan') || RegExp(r'^r[\s.\d]').hasMatch(code);
  }

  static double startSortKey(Map<String, dynamic> shift) {
    final name = shift['name']?.toString() ?? '';
    final code = shift['code']?.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (RegExp(r'12\s*صباح').hasMatch(name) ||
        RegExp(r'^sh\s*12(\.0)?\s*m$').hasMatch(code)) {
      return 24;
    }
    final startRaw = shift['startTime'];
    final start = startRaw is num
        ? startRaw.toDouble()
        : parseTimeToFloat('${shift['startTimeStored'] ?? shift['startTime'] ?? ''}');
    if (start < 1) return start + 24;
    return start;
  }

  static void sortShiftsForDisplay(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final aRamadan = isRamadanShift(a);
      final bRamadan = isRamadanShift(b);
      if (aRamadan != bRamadan) return aRamadan ? 1 : -1;
      final diff = startSortKey(a).compareTo(startSortKey(b));
      if (diff != 0) return diff;
      return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
    });
  }
}
