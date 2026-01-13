import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/excel_seed_parser.dart';
import '../../data/seed_utils.dart';
import '../../data/dsf_account_service.dart';
import '../../data/seed_firestore_writer.dart';

class SeedImportController extends GetxController {
  final ExcelSeedParser _parser;
  final SeedFirestoreWriter _writer;
  final DsfAccountService _dsfAccounts;

  SeedImportController(this._parser, this._writer, this._dsfAccounts);

  final isRunning = false.obs;
  final progress = 0.0.obs;
  final status = ''.obs;
  final lastResult = Rxn<SeedImportResult>();
  final error = RxnString();
  final dsfCreated = 0.obs;
  final dsfFailed = 0.obs;

  Future<void> importFromBundledExcelAsset() async {
    isRunning.value = true;
    progress.value = 0;
    status.value = 'Loading Excel asset...';
    error.value = null;
    lastResult.value = null;
    dsfCreated.value = 0;
    dsfFailed.value = 0;

    try {
      final data = await rootBundle.load(
        'SECTION DSF TSA ALL DIST KARCHI HID SALE 2025.xlsx',
      );
      final bytes = data.buffer.asUint8List();

      status.value = 'Parsing TSA sheets...';
      final tsaSheets = _parser.parseTsaSheets(bytes);

      status.value = 'Parsing distributor sheets...';
      final distributorSheets = _parser.parseDistributorSheets(bytes);

      status.value =
          'Uploading to Firestore (tsas=${tsaSheets.length}, distributors=${distributorSheets.length})...';

      SeedImportResult result = await _writer.write(
        tsaSheets: tsaSheets,
        distributorSheets: distributorSheets,
        onProgress: (done, total) {
          if (total <= 0) return;
          progress.value = done / total;
        },
      );

      status.value = 'Creating DSF accounts from TSAs...';
      var created = 0;
      var failed = 0;
      for (final sheet in tsaSheets) {
        final tsaId = slugifyId(sheet.sheetName);
        try {
          final existing = await _dsfAccounts.getByTsaId(tsaId);
          if (existing != null) {
            continue;
          }
          await _dsfAccounts.createAccount(
            tsaId: tsaId,
            name: sheet.tsaName,
            distributorId: tsaId,
          );
          created++;
        } catch (_) {
          failed++;
        }
      }
      dsfCreated.value = created;
      dsfFailed.value = failed;

      lastResult.value = result;
      status.value = failed > 0
          ? 'Import completed (DSF created: $created, failed: $failed)'
          : 'Import completed (DSF created: $created)';
    } catch (e) {
      error.value = e.toString();
      status.value = 'Import failed';
    } finally {
      isRunning.value = false;
    }
  }
}
