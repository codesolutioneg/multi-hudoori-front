import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/shift_grid/shift_grid_import_untracked_panel.dart';

class ShiftGridImportStorage {
  static String _key(String gridId) => 'shift_grid_untracked_$gridId';

  static Future<void> save(
    String gridId,
    List<ShiftGridUntrackedUser> users,
    String message,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (users.isEmpty) {
      await prefs.remove(_key(gridId));
      return;
    }
    await prefs.setString(
      _key(gridId),
      jsonEncode({
        'message': message,
        'savedAt': DateTime.now().toIso8601String(),
        'users': users
            .map(
              (u) => {
                'excelRow': u.excelRow,
                'code': u.code,
                'excelName': u.excelName,
                'excelJob': u.excelJob,
                'filledShiftCells': u.filledShiftCells,
                'reason': u.reason,
              },
            )
            .toList(),
      }),
    );
  }

  static Future<({List<ShiftGridUntrackedUser> users, String message})?> load(String gridId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(gridId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final users = ((map['users'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ShiftGridUntrackedUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (users.isEmpty) return null;
      return (users: users, message: map['message']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String gridId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(gridId));
  }
}
