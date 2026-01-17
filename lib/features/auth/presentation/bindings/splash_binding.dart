import 'package:get/get.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class SplashBinding extends Bindings {
  @override
  void dependencies() {
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
      Get.put(DistributorsRemoteDataSource(FirebaseFirestore.instance));
    }

    putLazyIfMissing<AuthRepositoryImpl>(
      () => AuthRepositoryImpl(
        Get.find<AuthRemoteDataSource>(),
        Get.find<UserProfileRemoteDataSource>(),
        Get.find<DistributorsRemoteDataSource>(),
        Get.find(),
        Get.find(),
        Get.find<SessionService>(),
        FirebaseFirestore.instance,
      ),
    );

    putLazyIfMissing<LoadSessionUseCase>(
      () => LoadSessionUseCase(Get.find<AuthRepositoryImpl>()),
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

    putLazyIfMissing<SplashController>(
      () => SplashController(
        Get.find<SessionService>(),
        Get.find<LoadSessionUseCase>(),
      ),
    );
  }
}
