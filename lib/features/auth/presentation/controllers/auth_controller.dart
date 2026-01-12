import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  String _formatAuthError(FirebaseAuthException e) {
    final message = e.message ?? '';
    final combined = '${e.code} $message'.toLowerCase();
    if (combined.contains('configuration_not_found') ||
        combined.contains('configuration-not-found')) {
      return [
        'Firebase Auth configuration not found.',
        'Fix:',
        '1) Firebase Console → Authentication → Get started',
        '2) Sign-in method → Email/Password ON (if using email login)',
        '3) Project settings → Your apps: confirm Android package name matches',
        '4) Rebuild: flutter clean → flutter pub get → flutter run',
      ].join('\n');
    }
    return [
      'FirebaseAuthException: ${e.code}',
      if (message.isNotEmpty) message,
    ].join('\n');
  }

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
    } on FirebaseAuthException catch (e, st) {
      error.value = _formatAuthError(e);
      debugPrint(error.value);
      debugPrintStack(stackTrace: st);
    } catch (e, st) {
      error.value = e.toString();
      debugPrint(error.value);
      debugPrintStack(stackTrace: st);
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
