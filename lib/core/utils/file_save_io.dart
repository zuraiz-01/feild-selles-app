import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveBytesToFileImpl({
  required String fileName,
  required Uint8List bytes,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
