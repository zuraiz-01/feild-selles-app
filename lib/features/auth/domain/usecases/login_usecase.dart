import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repo;

  LoginUseCase(this._repo);

  Future<UserProfile> call({required String email, required String password}) {
    return _repo.loginWithEmailPassword(email: email, password: password);
  }
}
