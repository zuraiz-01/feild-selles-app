enum UserRole { admin, dsf, distributor }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'dsf':
      return UserRole.dsf;
    case 'distributor':
      return UserRole.distributor;
    default:
      throw StateError('Unknown role: $value');
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.dsf:
      return 'dsf';
    case UserRole.distributor:
      return 'distributor';
  }
}
