import 'dart:io';
import 'package:flutter/foundation.dart';

void downloadFileWeb({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError('downloadFileWeb is only supported on Web platform.');
}

/// Menyimpan file ke penyimpanan perangkat (Folder Downloads di Windows/macOS/Linux)
Future<String?> saveFileToDevice({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    Directory? targetDir;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final dl = Directory('$userProfile\\Downloads');
        if (dl.existsSync()) {
          targetDir = dl;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final dl = Directory('$home/Downloads');
        if (dl.existsSync()) {
          targetDir = dl;
        }
      }
    }

    targetDir ??= Directory.current;
    final file = File('${targetDir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[saveFileToDevice] File saved successfully to: ${file.path}');
    return file.path;
  } catch (e) {
    debugPrint('[saveFileToDevice] error: $e');
    return null;
  }
}

