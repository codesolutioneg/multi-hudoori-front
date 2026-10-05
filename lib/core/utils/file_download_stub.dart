import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_log.dart';

/// iOS/Android: save to the temp folder, then open the system share sheet
/// (Save to Files, WhatsApp, Mail, open in Excel…).
void downloadBase64File(String base64, String filename, String mimeType) {
  final bytes = base64Decode(base64);
  unawaited(_saveAndShare(bytes, filename, mimeType));
}

Future<void> _saveAndShare(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  try {
    final dir = await getTemporaryDirectory();
    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: safeName)],
        sharePositionOrigin: _screenCenter(),
      ),
    );
  } catch (e) {
    appLog('download', 'save/share failed for $filename', e);
  }
}

/// iPad presents the share sheet as a popover and requires an anchor rect.
Rect? _screenCenter() {
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return null;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}
