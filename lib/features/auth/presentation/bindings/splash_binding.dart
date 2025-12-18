import 'package:get/get.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/session/session_service.dart';
import '../../../distributors/data/datasources/distributors_remote_ds.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../data/datasources/user_profile_remote_ds.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/load_session_usecase.dart';
import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
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
        Get.find(),
        Get.find(),
        Get.find<SessionService>(),
      ),
    );

    Get.lazyPut<LoadSessionUseCase>(
      () => LoadSessionUseCase(Get.find<AuthRepositoryImpl>()),
    );

    Get.lazyPut<SplashController>(
      () => SplashController(
        Get.find<SessionService>(),
        Get.find<LoadSessionUseCase>(),
      ),
    );
  }
}
