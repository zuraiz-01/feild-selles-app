import 'dart:typed_data';

import 'file_save_stub.dart'
    if (dart.library.html) 'file_save_web.dart'
    if (dart.library.io) 'file_save_io.dart';

Future<String?> saveBytesToUserFile({
  required String fileName,
  required Uint8List bytes,
}) {
  return saveBytesToFileImpl(fileName: fileName, bytes: bytes);
}
