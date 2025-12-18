import 'dart:io';

import '../../../duty/domain/repositories/duty_repository.dart';
import '../../domain/export/excel_exporter.dart';
import '../repositories/reports_repository.dart';

class BuildDailyReportUseCase {
  final DutyRepository _dutyRepository;
  final ExcelExporter _excelExporter;
  final ReportsRepository _reportsRepository;

  BuildDailyReportUseCase(
    this._dutyRepository,
    this._excelExporter,
    this._reportsRepository,
  );

  Future<ExcelExportResult> call({
    required String dutyId,
    required String distributorId,
    required String dsfId,
    required String dateKey,
    required bool upload,
  }) async {
    final duty = await _dutyRepository.getDuty(dutyId);

    final result = await _excelExporter.export(
      fileName: 'daily_${dsfId}_$dateKey.xlsx',
      sheetName: 'SUMMARY',
      headers: const [
        'duty_id',
        'dsf_id',
        'distributor_id',
        'start_at_utc',
        'end_at_utc',
        'status',
      ],
      rows: [
        [
          duty.id,
          duty.dsfId,
          duty.distributorId,
          duty.startAtUtc.toIso8601String(),
          duty.endAtUtc?.toIso8601String() ?? '',
          duty.status,
        ],
      ],
    );

    if (upload) {
      final file = File(result.filePath);
      await _reportsRepository.uploadDailyReportAndCreateMetadata(
        distributorId: distributorId,
        dsfId: dsfId,
        dateKey: dateKey,
        sizeBytes: result.sizeBytes,
        file: file,
      );
    }

    return result;
  }
}
