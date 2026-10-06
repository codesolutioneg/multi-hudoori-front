import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/di/injection.dart';

/// Signed-in employee's personal photo, fetched once per employee id.
abstract final class MyPhoto {
  static final ValueNotifier<Uint8List?> bytes = ValueNotifier(null);
  static String? _loadedFor;

  static Future<void> load(String? employeeId) async {
    if (employeeId == null || employeeId.isEmpty) {
      _loadedFor = null;
      bytes.value = null;
      return;
    }
    if (_loadedFor == employeeId) return;
    _loadedFor = employeeId;
    bytes.value = null;
    try {
      final file = await api.employeeDocumentGet(
        employeeId,
        documentType: 'personal_photo',
      );
      final mime = file['mimeType']?.toString() ?? '';
      final raw = file['base64']?.toString() ?? '';
      if (raw.isEmpty || (mime.isNotEmpty && !mime.startsWith('image/'))) return;
      final data = raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
      if (_loadedFor == employeeId) bytes.value = base64Decode(data);
    } catch (_) {
      // No photo uploaded or not permitted; initials are shown instead.
    }
  }
}
