import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class LoadSessionUseCase {
  final AuthRepository _repo;

  LoadSessionUseCase(this._repo);

  Future<UserProfile?> call() {
    return _repo.loadCurrentSessionProfile();
  }
}
