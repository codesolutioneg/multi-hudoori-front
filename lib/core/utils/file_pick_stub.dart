import '../../l10n/l10n_extension.dart';

class PickedExcelFile {
  const PickedExcelFile({required this.base64, required this.filename});

  final String base64;
  final String filename;
}

Future<PickedExcelFile?> pickExcelFile() async {
  throw UnsupportedError(tr('platform.importWebOnly'));
}

Future<String?> pickExcelBase64() async {
  throw UnsupportedError(tr('platform.importWebOnly'));
}

Future<({String base64, String mimeType})?> pickDocumentBase64() async {
  throw UnsupportedError(tr('platform.documentsWebOnly'));
}

Future<({String base64, String mimeType})?> pickImageBase64() async {
  throw UnsupportedError(tr('platform.imagesWebOnly'));
}
