import 'dart:convert';
import 'dart:html' as html;

const _key = 'hudoori_demo_prefill';

Map<String, String>? readDemoPrefillFromBrowser() {
  try {
    final raw = html.window.localStorage[_key];
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  } catch (_) {
    return null;
  }
}

void clearDemoPrefillInBrowser() {
  try {
    html.window.localStorage.remove(_key);
  } catch (_) {}
}
