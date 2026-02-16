import 'dart:typed_data';

Future<String?> saveBytesToFileImpl({
  required String fileName,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('File saving is not supported on this platform.');
}
