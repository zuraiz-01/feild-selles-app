import 'dart:io';

abstract class ReportsRepository {
  Future<void> uploadDailyReportAndCreateMetadata({
    required File file,
    required String distributorId,
    required String dsfId,
    required String dateKey,
    required int sizeBytes,
    String? sha256,
  });
}
