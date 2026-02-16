import 'dart:typed_data';

abstract class ReportsRepository {
  Future<void> uploadDailyReportAndCreateMetadata({
    required Uint8List bytes,
    required String distributorId,
    required String dsfId,
    required String dateKey,
    required int sizeBytes,
    String? sha256,
  });
}
