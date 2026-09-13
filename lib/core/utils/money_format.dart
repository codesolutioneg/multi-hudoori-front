import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat('#,##0.00', 'en_US');

/// Display money with thousands separators (e.g. 12,345.67) — same as advances.
String formatMoney(dynamic value, {String fallback = '0.00'}) {
  if (value == null) return fallback;
  if (value is num) return _moneyFormat.format(value.toDouble());
  final raw = value.toString().trim();
  if (raw.isEmpty) return fallback;
  final parsed = num.tryParse(raw.replaceAll(',', ''));
  if (parsed == null) return raw;
  return _moneyFormat.format(parsed.toDouble());
}

/// Parse user/API text that may contain comma grouping.
double? parseMoney(String? text) {
  final cleaned = text?.replaceAll(',', '').trim() ?? '';
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Format a numeric field for editable money inputs (empty when null/zero absent).
String formatMoneyField(dynamic value) {
  if (value == null) return '';
  if (value is num) {
    if (value == 0) return '0.00';
    return _moneyFormat.format(value.toDouble());
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return '';
  final parsed = num.tryParse(raw.replaceAll(',', ''));
  if (parsed == null) return raw;
  return _moneyFormat.format(parsed.toDouble());
}
