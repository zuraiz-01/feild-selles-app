import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelExportResult {
  final String filePath;
  final int sizeBytes;

  const ExcelExportResult({required this.filePath, required this.sizeBytes});
}

class ExcelExporter {
  Future<ExcelExportResult> export({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String sheetName = 'DATA',
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[sheetName];

    sheet.appendRow(headers.map(_cell).toList());
    for (final row in rows) {
      sheet.appendRow(row.map(_cell).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode excel');
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return ExcelExportResult(filePath: file.path, sizeBytes: bytes.length);
  }

  CellValue _cell(dynamic value) {
    if (value == null) {
      return TextCellValue('');
    }
    if (value is CellValue) {
      return value;
    }
    if (value is String) {
      return TextCellValue(value);
    }
    if (value is int) {
      return IntCellValue(value);
    }
    if (value is double) {
      return DoubleCellValue(value);
    }
    if (value is num) {
      return DoubleCellValue(value.toDouble());
    }
    if (value is bool) {
      return BoolCellValue(value);
    }
    if (value is DateTime) {
      return DateCellValue(
        year: value.year,
        month: value.month,
        day: value.day,
      );
    }
    return TextCellValue(value.toString());
  }
}
