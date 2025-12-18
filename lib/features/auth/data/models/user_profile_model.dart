import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/user_role.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileModel {
  final String uid;
  final String role;
  final String distributorId;

  const UserProfileModel({
    required this.uid,
    required this.role,
    required this.distributorId,
  });

  factory UserProfileModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User profile not found for uid=${doc.id}');
    }

    final role = data['role'];
    final distributorId = data['distributorId'];
    if (role is! String || distributorId is! String) {
      throw StateError('Invalid user profile schema for uid=${doc.id}');
    }

    return UserProfileModel(
      uid: doc.id,
      role: role,
      distributorId: distributorId,
    );
  }

  UserProfile toEntity({required UserRole effectiveRole}) {
    return UserProfile(
      uid: uid,
      role: effectiveRole,
      distributorId: distributorId,
    );
  }

  UserRole roleAsEnum() => userRoleFromString(role);
}
