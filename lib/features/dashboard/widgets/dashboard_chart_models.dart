import 'package:flutter/material.dart';

class ChartSliceData {
  const ChartSliceData({
    required this.label,
    required this.labelAr,
    required this.count,
    required this.color,
  });

  final String label;
  final String labelAr;
  final int count;
  final Color color;

  static ChartSliceData fromJson(Map<String, dynamic> json) {
    final hex = json['color']?.toString() ?? '#94A3B8';
    return ChartSliceData(
      label: json['label']?.toString() ?? '',
      labelAr: json['labelAr']?.toString() ?? json['label']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      color: _colorFromHex(hex),
    );
  }

  static Color _colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF94A3B8);
  }
}

class TrendPointData {
  const TrendPointData({
    required this.date,
    required this.absent,
    required this.late,
    required this.earlyLeave,
  });

  final String date;
  final int absent;
  final int late;
  final int earlyLeave;

  static TrendPointData fromJson(Map<String, dynamic> json) => TrendPointData(
        date: json['date']?.toString() ?? '',
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
        earlyLeave: (json['earlyLeave'] as num?)?.toInt() ?? 0,
      );
}

List<ChartSliceData> slicesFromJson(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => ChartSliceData.fromJson(Map<String, dynamic>.from(e))).toList();
}

List<TrendPointData> trendFromJson(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => TrendPointData.fromJson(Map<String, dynamic>.from(e))).toList();
}
