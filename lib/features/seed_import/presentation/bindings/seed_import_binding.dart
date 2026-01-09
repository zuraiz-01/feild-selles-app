import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../data/excel_seed_parser.dart';
import '../../data/seed_firestore_writer.dart';
import '../controllers/seed_import_controller.dart';

class SeedImportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExcelSeedParser>(() => ExcelSeedParser());
    Get.lazyPut<SeedFirestoreWriter>(
      () => SeedFirestoreWriter(FirebaseFirestore.instance),
    );
    Get.lazyPut<SeedImportController>(
      () => SeedImportController(
        Get.find<ExcelSeedParser>(),
        Get.find<SeedFirestoreWriter>(),
      ),
    );
  }
}

