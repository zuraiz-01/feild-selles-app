import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/services/session/session_service.dart';
import '../../domain/usecases/load_session_usecase.dart';

class SplashController extends GetxController {
  final SessionService _sessionService;
  final LoadSessionUseCase _loadSessionUseCase;

  SplashController(this._sessionService, this._loadSessionUseCase);

  @override
  void onReady() {
    super.onReady();
    bootstrap();
  }

  Future<void> bootstrap() async {
    try {
      await _sessionService.loadFromDisk();

      final profile = await _loadSessionUseCase();
      if (profile == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      _sessionService.setProfile(
        SessionUserProfile(
          uid: profile.uid,
          role: profile.role,
          distributorId: profile.distributorId,
        ),
      );

      switch (profile.role) {
        case UserRole.admin:
          Get.offAllNamed(AppRoutes.adminDashboard);
          return;
        case UserRole.dsf:
          Get.offAllNamed(AppRoutes.dsfHome);
          return;
        case UserRole.distributor:
          Get.offAllNamed(AppRoutes.distributorDashboard);
          return;
      }
    } catch (_) {
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
