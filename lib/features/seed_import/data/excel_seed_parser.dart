import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'seed_models.dart';
import 'seed_utils.dart';

class ExcelSeedParser {
  List<SeedTsaSheet> parseTsaSheets(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final out = <SeedTsaSheet>[];

    for (final entry in excel.tables.entries) {
      final sheetName = entry.key;
      final sheet = entry.value;
      if (sheet.maxRows < 8) continue;

      final tsaNameLine = _cellString(sheet, row: 4, col: 0); // A5
      if (tsaNameLine == null || !tsaNameLine.toUpperCase().contains('TSA')) {
        continue;
      }

      final tsaName = _extractAfterColon(tsaNameLine) ?? sheetName.trim();
      final avg2023Col = _findColByExactText(sheet: sheet, row: 5, text: 'AVG 2023');
      final filerCol = _findColByExactText(sheet: sheet, row: 5, text: 'FILLER');

      final periods = _extractPeriodsFromHeaderRows(
        sheet: sheet,
        labelRow: 5, // row 6 in Excel
        subHeaderRow: 6, // row 7 in Excel
      );

      final shops = <SeedShop>[];
      var blankStreak = 0;
      for (var row = 7; row < sheet.maxRows; row++) {
        final code = _cellString(sheet, row: row, col: 3); // D
        final name = _cellString(sheet, row: row, col: 1); // B
        final area = _cellString(sheet, row: row, col: 2); // C

        final isRowEmpty =
            (code == null || code.isEmpty) &&
            (name == null || name.isEmpty) &&
            (area == null || area.isEmpty);
        if (isRowEmpty) {
          blankStreak++;
          if (blankStreak >= 3) break;
          continue;
        }
        blankStreak = 0;

        if (code == null || code.trim().isEmpty) {
          continue;
        }

        final avg2023 =
            avg2023Col == null
                ? null
                : _cellDouble(sheet, row: row, col: avg2023Col);

        bool? isFiler;
        if (filerCol != null) {
          final filerRaw = _cellString(sheet, row: row, col: filerCol);
          if (filerRaw != null && filerRaw.trim().isNotEmpty) {
            final val = filerRaw.trim().toLowerCase();
            if (val == 'yes' || val == 'y' || val == 'true') {
              isFiler = true;
            } else if (val == 'no' || val == 'n' || val == 'false') {
              isFiler = false;
            }
          }
        }

        final sales = <SeedPeriod, SeedPeriodValue>{};
        for (final p in periods) {
          final canola = _cellDouble(sheet, row: row, col: p._groupStart);
          final corn = _cellDouble(sheet, row: row, col: p._groupStart + 1);
          final total = _cellDouble(sheet, row: row, col: p._groupStart + 2);
          if (canola == null && corn == null && total == null) continue;
          sales[p.period] = SeedPeriodValue(
            canola: canola ?? 0,
            corn: corn ?? 0,
            total: total ?? 0,
          );
        }

        shops.add(
          SeedShop(
            code: code.trim(),
            name: (name ?? '').trim(),
            area: (area ?? '').trim(),
            avg2023: avg2023,
            isFiler: isFiler,
            sales: sales,
          ),
        );
      }

      out.add(SeedTsaSheet(sheetName: sheetName, tsaName: tsaName, shops: shops));
    }

    return out;
  }

  List<SeedDistributorSheet> parseDistributorSheets(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final out = <SeedDistributorSheet>[];

    for (final entry in excel.tables.entries) {
      final sheetName = entry.key;
      final sheet = entry.value;
      if (sheet.maxRows < 6) continue;

      final headerRow = _detectDistributorHeaderRow(sheet);
      if (headerRow == null) continue;

      final distributorName = sheetName.trim();
      final periods = _extractPeriodsByLabels(
        sheet: sheet,
        labelRow: headerRow,
        groupStartMode: _GroupStartMode.labelIsStart,
      );

      final rows = <SeedDistributorPartyRow>[];
      var blankStreak = 0;
      for (var row = headerRow + 1; row < sheet.maxRows; row++) {
        final partyName = _cellString(sheet, row: row, col: 1); // B
        final area = _cellString(sheet, row: row, col: 2); // C
        final assignedTo = _cellString(sheet, row: row, col: 3); // D (TSA name)

        final isEmpty =
            (partyName == null || partyName.trim().isEmpty) &&
            (area == null || area.trim().isEmpty) &&
            (assignedTo == null || assignedTo.trim().isEmpty);
        if (isEmpty) {
          blankStreak++;
          if (blankStreak >= 3) break;
          continue;
        }
        blankStreak = 0;

        if (partyName == null || partyName.trim().isEmpty) continue;

        final sales = <SeedPeriod, SeedPeriodValue>{};
        for (final p in periods) {
          final canola = _cellDouble(sheet, row: row, col: p._groupStart);
          final corn = _cellDouble(sheet, row: row, col: p._groupStart + 1);
          final total = _cellDouble(sheet, row: row, col: p._groupStart + 2);
          if (canola == null && corn == null && total == null) continue;
          sales[p.period] = SeedPeriodValue(
            canola: canola ?? 0,
            corn: corn ?? 0,
            total: total ?? 0,
          );
        }

        rows.add(
          SeedDistributorPartyRow(
            partyName: partyName.trim(),
            area: (area ?? '').trim(),
            assignedTo: (assignedTo ?? '').trim(),
            sales: sales,
          ),
        );
      }

      out.add(
        SeedDistributorSheet(
          sheetName: sheetName,
          distributorName: distributorName,
          parties: rows,
        ),
      );
    }

    return out;
  }

  int? _detectDistributorHeaderRow(Sheet sheet) {
    for (var row = 0; row < sheet.maxRows && row < 12; row++) {
      final b = _cellString(sheet, row: row, col: 1);
      if (b != null && b.trim().toUpperCase() == 'PARTY NAME') {
        return row;
      }
    }
    return null;
  }

  List<_ParsedPeriod> _extractPeriodsFromHeaderRows({
    required Sheet sheet,
    required int labelRow,
    required int subHeaderRow,
  }) {
    final subHeaderCanolaCols = <int>{};
    final maxCols = _maxCols(sheet);
    for (var col = 0; col < maxCols; col++) {
      final v = _cellString(sheet, row: subHeaderRow, col: col);
      if (v != null && v.trim().toUpperCase() == 'CANOLA') {
        subHeaderCanolaCols.add(col);
      }
    }

    final periods = <_ParsedPeriod>[];
    for (var col = 0; col < maxCols; col++) {
      final label = _cellString(sheet, row: labelRow, col: col);
      if (label == null) continue;
      if (!label.toUpperCase().startsWith('SALE MONTH:')) continue;

      var groupStart = col - 2;
      if (groupStart < 0) continue;
      if (!subHeaderCanolaCols.contains(groupStart)) {
        if (subHeaderCanolaCols.contains(col)) {
          groupStart = col;
        } else {
          continue;
        }
      }

      periods.add(
        _ParsedPeriod(
          period: _parsePeriodLabel(label),
          groupStart: groupStart,
        ),
      );
    }

    return periods;
  }

  List<_ParsedPeriod> _extractPeriodsByLabels({
    required Sheet sheet,
    required int labelRow,
    required _GroupStartMode groupStartMode,
  }) {
    final periods = <_ParsedPeriod>[];
    final maxCols = _maxCols(sheet);
    for (var col = 0; col < maxCols; col++) {
      final label = _cellString(sheet, row: labelRow, col: col);
      if (label == null) continue;
      if (!label.toUpperCase().startsWith('SALE MONTH:')) continue;

      final groupStart =
          switch (groupStartMode) {
            _GroupStartMode.labelIsStart => col,
            _GroupStartMode.labelIsEnd => col - 2,
          };
      if (groupStart < 0) continue;

      periods.add(
        _ParsedPeriod(period: _parsePeriodLabel(label), groupStart: groupStart),
      );
    }
    return periods;
  }

  SeedPeriod _parsePeriodLabel(String rawLabel) {
    final cleaned = rawLabel
        .replaceFirst(RegExp(r'^SALE\\s+MONTH\\s*:\\s*', caseSensitive: false), '')
        .trim();

    final yearMatch = RegExp(r'\\b(\\d{4})\\b').firstMatch(cleaned);
    final year = yearMatch == null ? DateTime.now().year : int.parse(yearMatch[1]!);

    final range = RegExp(
      r'(JAN|FEB|FAB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\\s+TO\\s+(JAN|FEB|FAB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (range != null) {
      final start = monthNumberFromName(range[1]!);
      final end = monthNumberFromName(range[2]!);
      final sortKey = year * 100 + end;
      final id = '${year.toString().padLeft(4, '0')}-${start.toString().padLeft(2, '0')}_to_${end.toString().padLeft(2, '0')}';
      return SeedPeriod(
        id: slugifyId(id),
        label: cleaned,
        kind: 'range',
        sortKey: sortKey,
      );
    }

    final month = RegExp(
      r'\\b(JAN|FEB|FAB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\\b',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (month != null) {
      final m = monthNumberFromName(month[1]!);
      final sortKey = year * 100 + m;
      final id = '${year.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
      return SeedPeriod(
        id: slugifyId(id),
        label: cleaned,
        kind: 'month',
        sortKey: sortKey,
      );
    }

    return SeedPeriod(
      id: slugifyId(cleaned),
      label: cleaned,
      kind: 'other',
      sortKey: year * 100 + 99,
    );
  }

  int? _findColByExactText({
    required Sheet sheet,
    required int row,
    required String text,
  }) {
    final maxCols = _maxCols(sheet);
    for (var col = 0; col < maxCols; col++) {
      final v = _cellString(sheet, row: row, col: col);
      if (v != null && v.trim().toUpperCase() == text.toUpperCase()) {
        return col;
      }
    }
    return null;
  }

  String? _extractAfterColon(String s) {
    final idx = s.indexOf(':');
    if (idx == -1) return null;
    final rest = s.substring(idx + 1).trim();
    return rest.isEmpty ? null : rest;
  }

  String? _cellString(Sheet sheet, {required int row, required int col}) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    final v = cell.value;
    if (v == null) return null;

    if (v is TextCellValue) {
      return v.value.toString();
    }
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is BoolCellValue) return v.value.toString();
    if (v is DateCellValue) {
      return '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    if (v is FormulaCellValue) return v.toString();
    return v.toString();
  }

  double? _cellDouble(Sheet sheet, {required int row, required int col}) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    final v = cell.value;
    if (v == null) return null;

    if (v is IntCellValue) return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    if (v is TextCellValue) {
      final trimmed = v.value.toString().trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed.replaceAll(',', ''));
    }

    return null;
  }

  int _maxCols(Sheet sheet) {
    var max = 0;
    for (final row in sheet.rows) {
      if (row.length > max) max = row.length;
    }
    return max;
  }
}

enum _GroupStartMode { labelIsStart, labelIsEnd }

class _ParsedPeriod {
  final SeedPeriod period;
  final int _groupStart;

  const _ParsedPeriod({required this.period, required int groupStart})
    : _groupStart = groupStart;
}

class SeedDistributorPartyRow {
  final String partyName;
  final String area;
  final String assignedTo;
  final Map<SeedPeriod, SeedPeriodValue> sales;

  const SeedDistributorPartyRow({
    required this.partyName,
    required this.area,
    required this.assignedTo,
    required this.sales,
  });
}

class SeedDistributorSheet {
  final String sheetName;
  final String distributorName;
  final List<SeedDistributorPartyRow> parties;

  const SeedDistributorSheet({
    required this.sheetName,
    required this.distributorName,
    required this.parties,
  });
}
