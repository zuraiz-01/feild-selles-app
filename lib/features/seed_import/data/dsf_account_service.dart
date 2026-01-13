import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../firebase_options.dart';

class DsfAccount {
  final String tsaId;
  final String name;
  final String email;
  final String password;
  final String uid;
  final String distributorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DsfAccount({
    required this.tsaId,
    required this.name,
    required this.email,
    required this.password,
    required this.uid,
    required this.distributorId,
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

    return DsfAccount(
      tsaId: (data['tsaId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      password: (data['password'] as String?) ?? '',
      uid: (data['uid'] as String?) ?? '',
      distributorId: (data['distributorId'] as String?) ?? '',
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
      return DsfAccount.fromDoc(doc);
    });
  }

  Future<DsfAccount?> getByTsaId(String tsaId) async {
    final doc = await _col.doc(tsaId).get();
    if (!doc.exists) return null;
    return DsfAccount.fromDoc(doc);
  }

  String emailForTsa(String tsaId) => '$tsaId@field.local';

  String generatePassword({int length = 12}) {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*?';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[rand.nextInt(alphabet.length)],
    ).join();
  }

  Future<DsfAccount> createAccount({
    required String tsaId,
    required String name,
    required String distributorId,
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
    String? email,
    String? password,
  }) async {
    final existing = await _col.doc(tsaId).get();
    if (existing.exists) {
      return DsfAccount.fromDoc(existing);
    }

    final finalEmail = (email?.trim().isNotEmpty ?? false)
        ? email!.trim()
        : emailForTsa(tsaId);
    final finalPassword =
        (password?.trim().isNotEmpty ?? false) ? password!.trim() : generatePassword();
    final finalDistributorId =
        distributorId.trim().isEmpty ? tsaId : distributorId.trim();

    final signUpUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${DefaultFirebaseOptions.web.apiKey}',
    );
    final signUpRes = await _postJson(signUpUri, {
      'email': finalEmail,
      'password': finalPassword,
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
      'password': finalPassword,
      'uid': localId,
      'distributorId': finalDistributorId,
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
    required String password,
    required String distributorId,
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
  }) async {
    final existing = await _col.doc(tsaId).get();
    if (!existing.exists) {
      throw StateError('DSF account not found for TSA: $tsaId');
    }
    final current = DsfAccount.fromDoc(existing);
    final newEmail = email.trim();
    final newPassword = password.trim();
    final newDistributorId =
        distributorId.trim().isEmpty ? tsaId : distributorId.trim();

    if (newEmail.isEmpty || newPassword.isEmpty) {
      throw StateError('Email and password are required');
    }

    final needsAuthUpdate =
        newEmail != current.email || newPassword != current.password;
    if (needsAuthUpdate) {
      final idToken = await _signInForToken(
        email: current.email,
        password: current.password,
      );
      await _updateAuthUser(
        idToken: idToken,
        email: newEmail,
        password: newPassword,
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
      'password': newPassword,
      'distributorId': newDistributorId,
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
    final current = DsfAccount.fromDoc(existing);
    final idToken = await _signInForToken(
      email: current.email,
      password: current.password,
    );
    await _deleteAuthUser(idToken: idToken);

    await _firestore.collection('users').doc(current.uid).delete();
    await _col.doc(tsaId).delete();
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
          'center': {
            'lat': officeLat,
            'lng': officeLng,
          },
          'radiusMeters': officeRadiusMeters,
        },
      }, SetOptions(merge: true));
      return;
    }

    await ref.set({
      'name': name,
      'distributorId': distributorId,
      'officeGeofence': {
        'center': {
          'lat': officeLat,
          'lng': officeLng,
        },
        'radiusMeters': officeRadiusMeters,
      },
    });
  }

  Future<String> _signInForToken({
    required String email,
    required String password,
  }) async {
    final signInUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${DefaultFirebaseOptions.web.apiKey}',
    );
    final signInRes = await _postJson(signInUri, {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    final signInBody = await _parseBody(signInRes);
    if (signInRes.statusCode < 200 || signInRes.statusCode >= 300) {
      final err = signInBody['error'];
      throw StateError('REST signIn failed: ${err ?? signInBody}');
    }
    final token = signInBody['idToken'];
    if (token is! String) {
      throw StateError('REST signIn missing idToken');
    }
    return token;
  }

  Future<void> _updateAuthUser({
    required String idToken,
    required String email,
    required String password,
  }) async {
    final updateUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:update?key=${DefaultFirebaseOptions.web.apiKey}',
    );
    final updateRes = await _postJson(updateUri, {
      'idToken': idToken,
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    final updateBody = await _parseBody(updateRes);
    if (updateRes.statusCode < 200 || updateRes.statusCode >= 300) {
      final err = updateBody['error'];
      throw StateError('REST update failed: ${err ?? updateBody}');
    }
  }

  Future<void> _deleteAuthUser({required String idToken}) async {
    final deleteUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${DefaultFirebaseOptions.web.apiKey}',
    );
    final deleteRes = await _postJson(deleteUri, {'idToken': idToken});
    if (deleteRes.statusCode < 200 || deleteRes.statusCode >= 300) {
      final body = await _parseBody(deleteRes);
      final err = body['error'];
      throw StateError('REST delete failed: ${err ?? body}');
    }
  }

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) {
    return http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
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
