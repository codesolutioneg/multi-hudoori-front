import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PickedExcelFile {
  const PickedExcelFile({required this.base64, required this.filename});

  final String base64;
  final String filename;
}

Future<PickedExcelFile?> pickExcelFile() async {
  final completer = Completer<PickedExcelFile?>();
  final input = html.FileUploadInputElement()
    ..accept = '.xlsx,.xls,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ..style.display = 'none';

  void cleanup() => input.remove();

  input.onChange.listen((_) async {
    final file = input.files?.first;
    if (file == null) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      cleanup();
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is! String) {
        completer.complete(null);
        return;
      }
      final comma = result.indexOf(',');
      completer.complete(PickedExcelFile(
        base64: comma >= 0 ? result.substring(comma + 1) : result,
        filename: file.name,
      ));
    });
    reader.readAsDataUrl(file);
  });

  html.document.body?.append(input);
  input.click();
  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}

Future<String?> pickExcelBase64() async => (await pickExcelFile())?.base64;

Future<({String base64, String mimeType})?> pickDocumentBase64() async {
  final completer = Completer<({String base64, String mimeType})?>();
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,.png,.jpg,.jpeg,.webp,image/*,application/pdf'
    ..style.display = 'none';

  void cleanup() => input.remove();

  input.onChange.listen((_) async {
    final file = input.files?.first;
    if (file == null) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      cleanup();
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is! String) {
        completer.complete(null);
        return;
      }
      final comma = result.indexOf(',');
      completer.complete((
        base64: comma >= 0 ? result.substring(comma + 1) : result,
        mimeType: file.type.isNotEmpty ? file.type : 'application/octet-stream',
      ));
    });
    reader.readAsDataUrl(file);
  });

  html.document.body?.append(input);
  input.click();
  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}

Future<({String base64, String mimeType})?> pickImageBase64() async {
  final completer = Completer<({String base64, String mimeType})?>();
  final input = html.FileUploadInputElement()
    ..accept = '.png,.jpg,.jpeg,.webp,image/*'
    ..style.display = 'none';

  void cleanup() => input.remove();

  input.onChange.listen((_) async {
    final file = input.files?.first;
    if (file == null) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      cleanup();
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is! String) {
        completer.complete(null);
        return;
      }
      final comma = result.indexOf(',');
      completer.complete((
        base64: comma >= 0 ? result.substring(comma + 1) : result,
        mimeType: file.type.isNotEmpty ? file.type : 'image/png',
      ));
    });
    reader.readAsDataUrl(file);
  });

  html.document.body?.append(input);
  input.click();
  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}
