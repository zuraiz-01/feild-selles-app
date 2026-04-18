import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../firebase_options.dart';

class DsfAccount {
  final String tsaId;
  final String name;
  final String email;
  final String uid;
  final String distributorId;
  final String? photoUrl;
  final int? shopVisitWaitSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DsfAccount({
    required this.tsaId,
    required this.name,
    required this.email,
    required this.uid,
    required this.distributorId,
    this.photoUrl,
    this.shopVisitWaitSeconds,
    this.createdAt,
    this.updatedAt,
  });

  factory DsfAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime? readTimestamp(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return null;
    }

    int? readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    String? readPhotoUrl(Map<String, dynamic> source) {
      const keys = <String>[
        'photoUrl',
        'photoURL',
        'profilePhotoUrl',
        'avatarUrl',
      ];
      for (final key in keys) {
        final raw = source[key];
        if (raw is String) {
          final cleaned = raw.trim();
          if (cleaned.isNotEmpty) return cleaned;
        }
      }
      return null;
    }

    final photoUrl = readPhotoUrl(data);

    return DsfAccount(
      tsaId: (data['tsaId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      uid: (data['uid'] as String?) ?? '',
      distributorId: (data['distributorId'] as String?) ?? '',
      photoUrl: photoUrl,
      shopVisitWaitSeconds: readInt(data['shopVisitWaitSeconds']),
      createdAt: readTimestamp(data['createdAt']),
      updatedAt: readTimestamp(data['updatedAt']),
    );
  }
}

class DsfAccountService {
  final FirebaseFirestore _firestore;

  DsfAccountService(this._firestore);

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('dsfAccounts');

  Stream<DsfAccount?> watchByTsaId(String tsaId) {
    return _col.doc(tsaId).snapshots().map((doc) {
      if (!doc.exists) return null;
      unawaited(_scrubLegacyPassword(doc));
      return DsfAccount.fromDoc(doc);
    });
  }

  Future<DsfAccount?> getByTsaId(String tsaId) async {
    final doc = await _col.doc(tsaId).get();
    if (!doc.exists) return null;
    await _scrubLegacyPassword(doc);
    return DsfAccount.fromDoc(doc);
  }

  String emailForTsa(String tsaId) => '$tsaId@field.local';

  Future<DsfAccount> createAccount({
    required String tsaId,
    required String name,
    required String distributorId,
    String? photoUrl,
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
    int? shopVisitWaitSeconds,
    String? email,
    String? password,
  }) async {
    final existing = await _col.doc(tsaId).get();
    if (existing.exists) {
      await _scrubLegacyPassword(existing);
      return DsfAccount.fromDoc(existing);
    }

    final trimmedPassword = password?.trim() ?? '';
    if (trimmedPassword.isEmpty) {
      throw StateError('Password is required when creating a DSF account.');
    }

    final finalEmail = (email?.trim().isNotEmpty ?? false)
        ? email!.trim()
        : emailForTsa(tsaId);
    final finalDistributorId = distributorId.trim().isEmpty
        ? tsaId
        : distributorId.trim();
    final cleanedPhotoUrl = photoUrl?.trim();

    final signUpUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${DefaultFirebaseOptions.web.apiKey}',
    );
    final signUpRes = await _postJson(signUpUri, {
      'email': finalEmail,
      'password': trimmedPassword,
      'returnSecureToken': true,
    });
    final signUpBody = await _parseBody(signUpRes);
    if (signUpRes.statusCode < 200 || signUpRes.statusCode >= 300) {
      final err = signUpBody['error'];
      final message = (err is Map<String, dynamic>) ? err['message'] : null;
      if (message == 'EMAIL_EXISTS') {
        final existing = await _col
            .where('email', isEqualTo: finalEmail)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          return DsfAccount.fromDoc(existing.docs.first);
        }
        throw StateError(
          'Email already exists in Firebase Auth.\n'
          'Open TSA account and Update/Delete, or remove the user in Firebase Console.',
        );
      }
      throw StateError('REST signUp failed: ${err ?? signUpBody}');
    }

    final localId = signUpBody['localId'];
    if (localId is! String) {
      throw StateError('REST signUp missing localId');
    }

    await _writeUserProfile(uid: localId, distributorId: finalDistributorId);
    await _ensureDistributor(
      distributorId: finalDistributorId,
      name: name.trim(),
      officeLat: officeLat,
      officeLng: officeLng,
      officeRadiusMeters: officeRadiusMeters,
    );

    final now = FieldValue.serverTimestamp();
    await _col.doc(tsaId).set({
      'tsaId': tsaId,
      'name': name.trim(),
      'email': finalEmail,
      'uid': localId,
      'distributorId': finalDistributorId,
      if (cleanedPhotoUrl != null && cleanedPhotoUrl.isNotEmpty)
        'photoUrl': cleanedPhotoUrl,
      if (shopVisitWaitSeconds != null && shopVisitWaitSeconds >= 0)
        'shopVisitWaitSeconds': shopVisitWaitSeconds,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final saved = await _col.doc(tsaId).get();
    return DsfAccount.fromDoc(saved);
  }

  Future<DsfAccount> updateAccount({
    required String tsaId,
    required String name,
    required String email,
    required String distributorId,
    String? photoUrl,
    bool clearPhoto = false,
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
    int? shopVisitWaitSeconds,
  }) async {
    final existing = await _col.doc(tsaId).get();
    if (!existing.exists) {
      throw StateError('DSF account not found for TSA: $tsaId');
    }
    final current = DsfAccount.fromDoc(existing);
    final newEmail = email.trim();
    final newDistributorId = distributorId.trim().isEmpty
        ? tsaId
        : distributorId.trim();
    final cleanedPhotoUrl = photoUrl?.trim();

    if (newEmail.isEmpty) {
      throw StateError('Email is required');
    }

    if (newEmail != current.email) {
      throw StateError(
        'Email changes require a trusted backend or Firebase Console.',
      );
    }

    await _writeUserProfile(uid: current.uid, distributorId: newDistributorId);
    await _ensureDistributor(
      distributorId: newDistributorId,
      name: name.trim(),
      officeLat: officeLat,
      officeLng: officeLng,
      officeRadiusMeters: officeRadiusMeters,
    );

    await _col.doc(tsaId).set({
      'name': name.trim(),
      'email': newEmail,
      'password': FieldValue.delete(),
      'distributorId': newDistributorId,
      if (clearPhoto)
        'photoUrl': FieldValue.delete()
      else if (cleanedPhotoUrl != null && cleanedPhotoUrl.isNotEmpty)
        'photoUrl': cleanedPhotoUrl,
      if (shopVisitWaitSeconds != null && shopVisitWaitSeconds >= 0)
        'shopVisitWaitSeconds': shopVisitWaitSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final saved = await _col.doc(tsaId).get();
    return DsfAccount.fromDoc(saved);
  }

  Future<void> deleteAccount({required String tsaId}) async {
    final existing = await _col.doc(tsaId).get();
    if (!existing.exists) {
      return;
    }
    throw StateError(
      'Deleting the Firebase Auth user now requires Firebase Console or a trusted admin function.',
    );
  }

  Future<void> _writeUserProfile({
    required String uid,
    required String distributorId,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'role': 'dsf',
      'distributorId': distributorId,
    }, SetOptions(merge: true));
  }

  Future<void> _scrubLegacyPassword(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null || !data.containsKey('password')) return;
    try {
      await doc.reference.update({'password': FieldValue.delete()});
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  Future<void> _ensureDistributor({
    required String distributorId,
    required String name,
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
  }) async {
    if (officeLat == null || officeLng == null || officeRadiusMeters == null) {
      return;
    }

    final ref = _firestore.collection('distributors').doc(distributorId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.set({
        'name': name,
        'distributorId': distributorId,
        'officeGeofence': {
          'center': {'lat': officeLat, 'lng': officeLng},
          'radiusMeters': officeRadiusMeters,
        },
      }, SetOptions(merge: true));
      return;
    }

    await ref.set({
      'name': name,
      'distributorId': distributorId,
      'officeGeofence': {
        'center': {'lat': officeLat, 'lng': officeLng},
        'radiusMeters': officeRadiusMeters,
      },
    });
  }

  Future<http.Response> _postJson(Uri uri, Map<String, dynamic> body) {
    return http.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  Future<Map<String, dynamic>> _parseBody(http.Response res) async {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'raw': res.body};
    }
  }
}
