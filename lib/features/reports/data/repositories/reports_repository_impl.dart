import 'dart:io';

import '../../domain/repositories/reports_repository.dart';
import '../datasources/report_storage_ds.dart';
import '../datasources/reports_remote_ds.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportStorageDataSource _storage;
  final ReportsRemoteDataSource _remote;

  ReportsRepositoryImpl(this._storage, this._remote);

  @override
  Future<void> uploadDailyReportAndCreateMetadata({
    required File file,
    required String distributorId,
    required String dsfId,
    required String dateKey,
    required int sizeBytes,
    String? sha256,
  }) async {
    await _storage.uploadDailyReport(
      file: file,
      distributorId: distributorId,
      dsfId: dsfId,
      dateKey: dateKey,
    );

    final storagePath = _storage.dailyReportPath(
      distributorId: distributorId,
      dsfId: dsfId,
      dateKey: dateKey,
    );

    await _remote.createReportFileMetadata(
      distributorId: distributorId,
      dsfId: dsfId,
      reportType: 'daily',
      dateKey: dateKey,
      storagePath: storagePath,
      sizeBytes: sizeBytes,
      sha256: sha256,
    );
  }
}
