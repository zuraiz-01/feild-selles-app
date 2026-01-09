import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/excel_seed_parser.dart';
import '../../data/seed_firestore_writer.dart';

class SeedImportController extends GetxController {
  final ExcelSeedParser _parser;
  final SeedFirestoreWriter _writer;

  SeedImportController(this._parser, this._writer);

  final isRunning = false.obs;
  final progress = 0.0.obs;
  final status = ''.obs;
  final lastResult = Rxn<SeedImportResult>();
  final error = RxnString();

  Future<void> importFromBundledExcelAsset() async {
    isRunning.value = true;
    progress.value = 0;
    status.value = 'Loading Excel asset...';
    error.value = null;
    lastResult.value = null;

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

      lastResult.value = result;
      status.value = 'Import completed';
    } catch (e) {
      error.value = e.toString();
      status.value = 'Import failed';
    } finally {
      isRunning.value = false;
    }
  }
}
