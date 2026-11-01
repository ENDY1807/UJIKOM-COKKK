import 'dart:typed_data';

void downloadFileWeb({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError('downloadFileWeb is only supported on Web platform.');
}

