import '../entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<UserProfile?> loadCurrentSessionProfile();

  Future<void> logout();
}
