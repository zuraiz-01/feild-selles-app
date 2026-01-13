import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/domain/services/geofence_policy.dart';
import '../../core/services/location/location_service.dart';
import '../../core/services/session/session_service.dart';
import '../../features/auth/data/datasources/auth_remote_ds.dart';
import '../../features/auth/data/datasources/user_profile_remote_ds.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/distributors/data/datasources/distributors_remote_ds.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SessionService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(GeofencePolicy(), permanent: true);

    void putLazyIfMissing<T>(T Function() builder) {
      if (Get.isRegistered<T>()) return;
      Get.lazyPut<T>(builder, fenix: true);
    }

    putLazyIfMissing<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(FirebaseAuth.instance),
    );
    putLazyIfMissing<UserProfileRemoteDataSource>(
      () => UserProfileRemoteDataSource(FirebaseFirestore.instance),
    );
    if (!Get.isRegistered<DistributorsRemoteDataSource>()) {
      Get.put(
        DistributorsRemoteDataSource(FirebaseFirestore.instance),
        permanent: true,
      );
    }
    putLazyIfMissing<AuthRepositoryImpl>(
      () => AuthRepositoryImpl(
        Get.find<AuthRemoteDataSource>(),
        Get.find<UserProfileRemoteDataSource>(),
        Get.find<DistributorsRemoteDataSource>(),
        Get.find<LocationService>(),
        Get.find<GeofencePolicy>(),
        Get.find<SessionService>(),
      ),
    );
    putLazyIfMissing<LoginUseCase>(
      () => LoginUseCase(Get.find<AuthRepositoryImpl>()),
    );
    putLazyIfMissing<LogoutUseCase>(
      () => LogoutUseCase(Get.find<AuthRepositoryImpl>()),
    );
    putLazyIfMissing<AuthController>(
      () => AuthController(
        Get.find<SessionService>(),
        Get.find<LoginUseCase>(),
        Get.find<LogoutUseCase>(),
      ),
    );
  }
}
