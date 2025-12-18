import '../../../../core/models/user_role.dart';

class UserProfile {
  final String uid;
  final UserRole role;
  final String distributorId;

  const UserProfile({
    required this.uid,
    required this.role,
    required this.distributorId,
  });
}
