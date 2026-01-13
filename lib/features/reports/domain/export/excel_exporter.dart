import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelExportResult {
  final String filePath;
  final int sizeBytes;

  const ExcelExportResult({required this.filePath, required this.sizeBytes});
}

class ExcelSheet {
  final String name;
  final List<String> headers;
  final List<List<dynamic>> rows;

  const ExcelSheet({
    required this.name,
    required this.headers,
    required this.rows,
  });
}

class ExcelExporter {
  Future<ExcelExportResult> export({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String sheetName = 'DATA',
  }) {
    return exportWorkbook(
      fileName: fileName,
      sheets: [
        ExcelSheet(name: sheetName, headers: headers, rows: rows),
      ],
    );
  }

  Future<ExcelExportResult> exportWorkbook({
    required String fileName,
    required List<ExcelSheet> sheets,
  }) async {
    final excel = Excel.createExcel();

    for (final data in sheets) {
      final Sheet sheet = excel[data.name];
      sheet.appendRow(data.headers.map(_cell).toList());
      for (final row in data.rows) {
        sheet.appendRow(row.map(_cell).toList());
      }
    }

    // Drop the default sheet if unused to avoid an empty tab.
    if (sheets.where((s) => s.name == 'Sheet1').isEmpty &&
        excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
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
      return TextCellValue(value.toIso8601String());
    }
    return TextCellValue(value.toString());
  }
}
