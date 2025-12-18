import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ReportStorageDataSource {
  final FirebaseStorage _storage;

  ReportStorageDataSource(this._storage);

  Future<void> uploadDailyReport({
    required File file,
    required String distributorId,
    required String dsfId,
    required String dateKey,
  }) async {
    final path = 'reports/$distributorId/dsf/$dsfId/daily/$dateKey.xlsx';
    final ref = _storage.ref().child(path);
    await ref.putFile(
      file,
      SettableMetadata(
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    );
  }

  String dailyReportPath({
    required String distributorId,
    required String dsfId,
    required String dateKey,
  }) {
    return 'reports/$distributorId/dsf/$dsfId/daily/$dateKey.xlsx';
  }
}
