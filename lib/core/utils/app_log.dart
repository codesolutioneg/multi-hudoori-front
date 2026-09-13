import 'package:flutter/foundation.dart';

/// Debug-only logging for tracing config toggles and API calls.
void appLog(String tag, String message, [Object? detail]) {
  if (!kDebugMode) return;
  final suffix = detail == null ? '' : ' | $detail';
  debugPrint('[$tag] $message$suffix');
}
