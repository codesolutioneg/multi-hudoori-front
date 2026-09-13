import '../../l10n/l10n_extension.dart';

Future<String?> pickExcelBase64() async {
  throw UnsupportedError(tr('platform.importWebOnly'));
}

Future<({String base64, String mimeType})?> pickDocumentBase64() async {
  throw UnsupportedError(tr('platform.documentsWebOnly'));
}

Future<({String base64, String mimeType})?> pickImageBase64() async {
  throw UnsupportedError(tr('platform.imagesWebOnly'));
}
