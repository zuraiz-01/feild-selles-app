import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile_model.dart';

class UserProfileRemoteDataSource {
  final FirebaseFirestore _firestore;

  UserProfileRemoteDataSource(this._firestore);

  Future<UserProfileModel> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return UserProfileModel.fromDoc(doc);
  }

  Future<bool> isAdminUid(String uid) async {
    final doc = await _firestore.collection('adminUids').doc(uid).get();
    return doc.exists;
  }
}
