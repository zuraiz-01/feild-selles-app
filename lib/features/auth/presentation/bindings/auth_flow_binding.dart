import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../../../core/domain/services/geofence_policy.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../distributors/data/datasources/distributors_remote_ds.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../data/datasources/user_profile_remote_ds.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/load_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../controllers/auth_controller.dart';
import '../controllers/splash_controller.dart';

class AuthFlowBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(FirebaseAuth.instance),
    );
    Get.lazyPut<UserProfileRemoteDataSource>(
      () => UserProfileRemoteDataSource(FirebaseFirestore.instance),
    );
    Get.lazyPut<DistributorsRemoteDataSource>(
      () => DistributorsRemoteDataSource(FirebaseFirestore.instance),
    );

    Get.lazyPut<AuthRepositoryImpl>(
      () => AuthRepositoryImpl(
        Get.find<AuthRemoteDataSource>(),
        Get.find<UserProfileRemoteDataSource>(),
        Get.find<DistributorsRemoteDataSource>(),
        Get.find<LocationService>(),
        Get.find<GeofencePolicy>(),
        Get.find<SessionService>(),
      ),
    );

    Get.lazyPut<LoginUseCase>(
      () => LoginUseCase(Get.find<AuthRepositoryImpl>()),
    );
    Get.lazyPut<LoadSessionUseCase>(
      () => LoadSessionUseCase(Get.find<AuthRepositoryImpl>()),
    );
    Get.lazyPut<LogoutUseCase>(
      () => LogoutUseCase(Get.find<AuthRepositoryImpl>()),
    );

    Get.lazyPut<AuthController>(
      () => AuthController(
        Get.find<SessionService>(),
        Get.find<LoginUseCase>(),
        Get.find<LogoutUseCase>(),
      ),
    );

    Get.lazyPut<SplashController>(
      () => SplashController(
        Get.find<SessionService>(),
        Get.find<LoadSessionUseCase>(),
      ),
    );
  }
}
