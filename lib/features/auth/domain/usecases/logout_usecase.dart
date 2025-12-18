import '../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository _repo;

  LogoutUseCase(this._repo);

  Future<void> call() => _repo.logout();
}
