import 'package:get/get.dart';

import '../../core/domain/services/geofence_policy.dart';
import '../../core/services/location/location_service.dart';
import '../../core/services/session/session_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SessionService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(GeofencePolicy(), permanent: true);
  }
}
