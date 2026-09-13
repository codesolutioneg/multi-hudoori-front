import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';

/// Mirrors biotime_integration shift_grid_widget.css cell colors.
class ShiftGridCellStyle {
  const ShiftGridCellStyle({required this.background, required this.foreground, this.fontWeight});

  final Color background;
  final Color foreground;
  final FontWeight? fontWeight;

  static ShiftGridCellStyle forCell(Map<String, dynamic>? cell, {bool isFriday = false}) {
    if (cell == null) {
      return const ShiftGridCellStyle(
        background: Colors.white,
        foreground: Color(0xFF0F172A),
      );
    }
    if (cell['is_excluded'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFF6C757D),
        foreground: Colors.white,
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_sick'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFFFD6D6),
        foreground: Color(0xFF842029),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_annual_leave'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFCFE2FF),
        foreground: Color(0xFF084298),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_off'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFF90EE90),
        foreground: Color(0xFF155724),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_finished'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFE8DEF8),
        foreground: Color(0xFF4A148C),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_resignation'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFFFE0E0),
        foreground: Color(0xFF7F1D1D),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_work_absence'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFFFF0E6),
        foreground: Color(0xFF9A3412),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_work_injury'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFFFCDD2),
        foreground: Color(0xFFB71C1C),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_marriage_leave'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFD1E7DD),
        foreground: Color(0xFF0F5132),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['is_present'] == true && (cell['shift_code'] == null || cell['shift_code'] == '')) {
      return const ShiftGridCellStyle(
        background: Color(0xFFD1E7DD),
        foreground: Color(0xFF0F5132),
        fontWeight: FontWeight.bold,
      );
    }
    if (cell['shift_code'] != null && cell['shift_code'] != '') {
      return ShiftGridCellStyle(
        background: cell['is_bus_delay'] == true ? const Color(0xFFFFF3CD) : const Color(0xFFE8F5E9),
        foreground: const Color(0xFF2E7D32),
        fontWeight: FontWeight.w600,
      );
    }
    if (cell['is_bus_delay'] == true) {
      return const ShiftGridCellStyle(
        background: Color(0xFFFFF3CD),
        foreground: Color(0xFF856404),
        fontWeight: FontWeight.bold,
      );
    }
    return ShiftGridCellStyle(
      background: isFriday ? const Color(0xFFF1F5F9) : Colors.white,
      foreground: const Color(0xFF0F172A),
    );
  }

  static String displayLabel(Map<String, dynamic>? cell) {
    if (cell == null) return '';
    final label = cell['display_label']?.toString();
    if (label != null && label.isNotEmpty) return label;
    if (cell['is_excluded'] == true) return tr('shiftGrid.cell.excluded');
    if (cell['is_sick'] == true) return tr('shiftGrid.cell.sick');
    if (cell['is_annual_leave'] == true) return tr('shiftGrid.cell.annual');
    if (cell['is_off'] == true) return 'off';
    if (cell['is_finished'] == true) return tr('shiftGrid.cell.finished');
    if (cell['is_resignation'] == true) return tr('shiftGrid.cell.resignation');
    if (cell['is_work_absence'] == true) return tr('shiftGrid.cell.absence');
    if (cell['is_work_injury'] == true) return tr('shiftGrid.cell.injury');
    if (cell['is_marriage_leave'] == true) return tr('shiftGrid.cell.marriage');
    if (cell['is_present'] == true && (cell['shift_code'] == null || cell['shift_code'] == '')) return tr('shiftGrid.cell.present');
    final code = cell['shift_code']?.toString() ?? '';
    if (code.isNotEmpty) return cell['is_bus_delay'] == true ? '$code 🚌' : code;
    if (cell['is_bus_delay'] == true) return tr('shiftGrid.cell.busDelay');
    return '';
  }

  static String cellSelectValue(Map<String, dynamic>? cell) {
    if (cell == null) return '';
    if (cell['is_excluded'] == true) return 'excluded';
    if (cell['is_sick'] == true) return 'sick';
    if (cell['is_annual_leave'] == true) return 'annual';
    if (cell['is_off'] == true) return 'off';
    if (cell['is_finished'] == true) return 'finished';
    if (cell['is_resignation'] == true) return 'resignation';
    if (cell['is_work_absence'] == true) return 'work_absence';
    if (cell['is_work_injury'] == true) return 'work_injury';
    if (cell['is_marriage_leave'] == true) return 'marriage';
    if (cell['is_bus_delay'] == true && (cell['shift_id'] == null || cell['shift_id'] == false)) return 'bus_delay';
    if (cell['is_present'] == true && (cell['shift_id'] == null || cell['shift_id'] == false)) return 'present';
    final shiftId = cell['shift_id'];
    if (shiftId != null && shiftId != false) {
      if (cell['is_bus_delay'] == true) return 'bus_$shiftId';
      return shiftId.toString();
    }
    return '';
  }
}
