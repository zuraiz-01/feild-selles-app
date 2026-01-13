import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../data/dsf_account_service.dart';

class SeedTsaBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DsfAccountService>(
      () => DsfAccountService(FirebaseFirestore.instance),
    );
  }
}
