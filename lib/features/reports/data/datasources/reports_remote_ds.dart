import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsRemoteDataSource {
  final FirebaseFirestore _firestore;

  ReportsRemoteDataSource(this._firestore);

  Future<void> createReportFileMetadata({
    required String distributorId,
    required String dsfId,
    required String reportType,
    required String dateKey,
    required String storagePath,
    required int sizeBytes,
    String? sha256,
  }) async {
    final docId = '${dsfId}_${reportType}_$dateKey';

    await _firestore.collection('reportFiles').doc(docId).set({
      'distributorId': distributorId,
      'dsfId': dsfId,
      'reportType': reportType,
      'dateKey': dateKey,
      'storage': {
        'storagePath': storagePath,
        'sizeBytes': sizeBytes,
        if (sha256 != null) 'sha256': sha256,
      },
      'generatedAt': FieldValue.serverTimestamp(),
      'generatedBy': dsfId,
    });
  }
}
