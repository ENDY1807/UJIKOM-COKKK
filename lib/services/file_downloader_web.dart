import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadFileWeb({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  Timer(const Duration(seconds: 10), () {
    web.URL.revokeObjectURL(url);
  });
}
