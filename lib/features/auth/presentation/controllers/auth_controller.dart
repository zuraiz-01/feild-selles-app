import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/services/session/session_service.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

class AuthController extends GetxController {
  final SessionService _sessionService;
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;

  AuthController(this._sessionService, this._loginUseCase, this._logoutUseCase);

  final email = ''.obs;
  final password = ''.obs;
  final isLoading = false.obs;
  final error = RxnString();

  Future<void> login() async {
    final emailValue = email.value.trim();
    final passwordValue = password.value;
    if (emailValue.isEmpty || passwordValue.isEmpty) {
      error.value = 'Email and password are required';
      return;
    }

    isLoading.value = true;
    error.value = null;
    try {
      final profile = await _loginUseCase(
        email: emailValue,
        password: passwordValue,
      );
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
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    isLoading.value = true;
    error.value = null;
    try {
      await _logoutUseCase();
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
