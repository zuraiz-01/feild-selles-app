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
    final visits = await _dutyRepository.getShopVisits(dutyId);

    final totalStock = visits.fold<double>(
      0,
      (sum, v) => sum + (v.stock ?? 0),
    );
    final totalPayment = visits.fold<double>(
      0,
      (sum, v) => sum + (v.payment ?? 0),
    );

    final result = await _excelExporter.exportWorkbook(
      fileName: 'daily_${dsfId}_$dateKey.xlsx',
      sheets: [
        ExcelSheet(
          name: 'SUMMARY',
          headers: const [
            'duty_id',
            'dsf_id',
            'distributor_id',
            'start_at_utc',
            'end_at_utc',
            'status',
            'visit_count',
            'total_stock',
            'total_payment',
          ],
          rows: [
            [
              duty.id,
              duty.dsfId,
              duty.distributorId,
              duty.startAtUtc.toIso8601String(),
              duty.endAtUtc?.toIso8601String() ?? '',
              duty.status,
              visits.length,
              totalStock,
              totalPayment,
            ],
          ],
        ),
        ExcelSheet(
          name: 'VISITS',
          headers: const [
            'shop_id',
            'shop_title',
            'stock',
            'payment',
            'distance_meters',
            'visit_started_at',
            'submitted_at',
            'submitted_lat',
            'submitted_lng',
            'notes',
          ],
          rows: visits
              .map(
                (v) => [
                  v.shopId,
                  v.shopTitle,
                  v.stock ?? '',
                  v.payment ?? '',
                  v.distanceMeters ?? '',
                  v.visitStartedAt?.toIso8601String() ?? '',
                  v.submittedAt?.toIso8601String() ?? '',
                  v.submittedLat ?? '',
                  v.submittedLng ?? '',
                  v.notes,
                ],
              )
              .toList(),
        ),
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
