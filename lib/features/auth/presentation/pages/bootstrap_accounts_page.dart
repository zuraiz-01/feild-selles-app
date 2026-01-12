import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/models/user_role.dart';
import '../../../../firebase_options.dart';

class BootstrapAccountsPage extends StatefulWidget {
  const BootstrapAccountsPage({super.key});

  @override
  State<BootstrapAccountsPage> createState() => _BootstrapAccountsPageState();
}

class _BootstrapAccountsPageState extends State<BootstrapAccountsPage> {
  static const String _bootstrapSecret = String.fromEnvironment(
    'BOOTSTRAP_SECRET',
    defaultValue: '',
  );

  final _adminEmail = TextEditingController(text: 'admin@field.local');
  final _adminPassword = TextEditingController(text: 'Admin@12345');
  final _adminDistributorId = TextEditingController(text: 'admin');

  final _dsfEmail = TextEditingController(text: 'dsf@field.local');
  final _dsfPassword = TextEditingController(text: 'Dsf@12345');
  final _dsfDistributorId = TextEditingController();

  bool _isLoading = false;
  String? _status;

  bool get _enabled => kDebugMode || _bootstrapSecret.isNotEmpty;

  @override
  void dispose() {
    _adminEmail.dispose();
    _adminPassword.dispose();
    _adminDistributorId.dispose();
    _dsfEmail.dispose();
    _dsfPassword.dispose();
    _dsfDistributorId.dispose();
    super.dispose();
  }

  Future<FirebaseApp> _bootstrapApp() async {
    final existing = Firebase.apps.where((a) => a.name == 'bootstrap');
    if (existing.isNotEmpty) return existing.first;

    return Firebase.initializeApp(
      name: 'bootstrap',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<void> _createAccount({
    required UserRole role,
    required String email,
    required String password,
    required String distributorId,
  }) async {
    setState(() {
      _isLoading = true;
      _status = null;
    });

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _createOrUpdateAccountViaRest(
          role: role,
          email: email,
          password: password,
          distributorId: distributorId,
        );
        return;
      }

      final app = await _bootstrapApp();
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);

      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw StateError('Create user failed: missing uid');
      }

      await firestore.collection('users').doc(uid).set({
        'role': userRoleToString(role),
        'distributorId': distributorId.trim(),
      });

      if (role == UserRole.admin) {
        await firestore.collection('adminUids').doc(uid).set({
          'createdAt': FieldValue.serverTimestamp(),
          'email': email.trim(),
        });
      }

      setState(() {
        _status =
            'Created ${userRoleToString(role)} user:\nemail=${email.trim()}\nuid=$uid';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = 'FirebaseAuthException: ${e.code}\n${e.message ?? ''}'.trim();
      });
    } on FirebaseException catch (e) {
      setState(() {
        _status = 'FirebaseException: ${e.code}\n${e.message ?? ''}'.trim();
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createOrUpdateAccountViaRest({
    required UserRole role,
    required String email,
    required String password,
    required String distributorId,
  }) async {
    final options = DefaultFirebaseOptions.currentPlatform;
    final projectId = options.projectId;
    final apiKey = DefaultFirebaseOptions.web.apiKey;
    final trimmedEmail = email.trim();
    final trimmedDistributorId = distributorId.trim();

    Future<http.Response> postJson(Uri uri, Map<String, dynamic> body) {
      return http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }

    Future<http.Response> putFirestoreDoc({
      required String idToken,
      required String collection,
      required String docId,
      required Map<String, dynamic> fields,
    }) {
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$docId',
      );
      return http.patch(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fields': fields}),
      );
    }

    Future<Map<String, dynamic>> parseBody(http.Response res) async {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{'raw': res.body};
      }
    }

    try {
      debugPrint('BOOTSTRAP: using REST flow');
      final signUpUri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
      );
      final signUpRes = await postJson(signUpUri, {
        'email': trimmedEmail,
        'password': password,
        'returnSecureToken': true,
      });
      final signUpBody = await parseBody(signUpRes);

      String uid;
      String idToken;

      if (signUpRes.statusCode >= 200 && signUpRes.statusCode < 300) {
        final localId = signUpBody['localId'];
        final token = signUpBody['idToken'];
        if (localId is! String || token is! String) {
          throw StateError('REST signUp missing localId/idToken');
        }
        uid = localId;
        idToken = token;
      } else {
        final err = signUpBody['error'];
        final message = (err is Map<String, dynamic>) ? err['message'] : null;
        if (message == 'EMAIL_EXISTS') {
          final signInUri = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
          );
          final signInRes = await postJson(signInUri, {
            'email': trimmedEmail,
            'password': password,
            'returnSecureToken': true,
          });
          final signInBody = await parseBody(signInRes);
          if (signInRes.statusCode < 200 || signInRes.statusCode >= 300) {
            final err = signInBody['error'];
            final message = (err is Map<String, dynamic>) ? err['message'] : null;
            if (message == 'INVALID_LOGIN_CREDENTIALS') {
              throw StateError(
                'This email already exists but the password is wrong.\n'
                'Fix: use the same password you used earlier, OR delete the user in Firebase Console → Authentication → Users, then retry.',
              );
            }
            throw StateError('REST signIn failed: ${err ?? signInBody}');
          }
          final localId = signInBody['localId'];
          final token = signInBody['idToken'];
          if (localId is! String || token is! String) {
            throw StateError('REST signIn missing localId/idToken');
          }
          uid = localId;
          idToken = token;
        } else {
          throw StateError('REST signUp failed: ${err ?? signUpBody}');
        }
      }

      final usersRes = await putFirestoreDoc(
        idToken: idToken,
        collection: 'users',
        docId: uid,
        fields: {
          'role': {'stringValue': userRoleToString(role)},
          'distributorId': {'stringValue': trimmedDistributorId},
        },
      );
      if (usersRes.statusCode < 200 || usersRes.statusCode >= 300) {
        final body = await parseBody(usersRes);
        final message = (body['error'] is Map<String, dynamic>)
            ? (body['error']['message'] ?? body['error']).toString()
            : body.toString();
        if (usersRes.statusCode == 404 &&
            message.toLowerCase().contains('database (default) does not exist')) {
          throw StateError(
            'Firestore is not enabled for this Firebase project yet.\n'
            'Open Firebase Console → Firestore Database → Create database.\n'
            'Then retry bootstrap (it will sign-in and write the profile).\n\n'
            'Details: $message',
          );
        }
        throw StateError('REST write users/$uid failed: ${usersRes.body}');
      }

      if (role == UserRole.admin) {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        final adminRes = await putFirestoreDoc(
          idToken: idToken,
          collection: 'adminUids',
          docId: uid,
          fields: {
            'email': {'stringValue': trimmedEmail},
            'createdAt': {'timestampValue': nowIso},
          },
        );
        if (adminRes.statusCode < 200 || adminRes.statusCode >= 300) {
          throw StateError('REST write adminUids/$uid failed: ${adminRes.body}');
        }
      }

      setState(() {
        _status =
            'Created/updated ${userRoleToString(role)} user via REST:\nemail=$trimmedEmail\nuid=$uid';
      });
    } catch (e) {
      setState(() {
        _status = 'REST bootstrap failed: $e\n\n'
            'If this is a network error, try switching network/VPN and retry.\n'
            'If Firestore write is denied, relax rules or run on an authenticated admin account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bootstrap Accounts')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Bootstrap is disabled.\n\nRun in debug mode or set --dart-define=BOOTSTRAP_SECRET=...',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bootstrap Accounts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Creates Firebase Auth users and writes:\n- users/{uid}: {role, distributorId}\n- adminUids/{uid} (admins only)',
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 8),
            const Text(
              'Note: On some Android emulators, email/password sign-up may fail due to reCAPTCHA config.\nThis screen auto-falls back to a REST bootstrap when needed.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Admin'),
          const SizedBox(height: 8),
          TextField(
            controller: _adminEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Admin email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adminPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Admin password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adminDistributorId,
            decoration: const InputDecoration(
              labelText: 'Admin distributorId (any string)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () => _createAccount(
                      role: UserRole.admin,
                      email: _adminEmail.text,
                      password: _adminPassword.text,
                      distributorId: _adminDistributorId.text,
                    ),
            child: const Text('Create Admin'),
          ),
          const SizedBox(height: 16),
          _sectionTitle('DSF'),
          const SizedBox(height: 8),
          TextField(
            controller: _dsfEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'DSF email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dsfPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'DSF password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dsfDistributorId,
            decoration: const InputDecoration(
              labelText: 'DSF distributorId (must exist in Firestore)',
              border: OutlineInputBorder(),
              hintText: 'e.g. distributor_karachi_01',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    if (_dsfDistributorId.text.trim().isEmpty) {
                      setState(() {
                        _status =
                            'DSF distributorId is required (must match a document id in `distributors`).';
                      });
                      return;
                    }
                    _createAccount(
                      role: UserRole.dsf,
                      email: _dsfEmail.text,
                      password: _dsfPassword.text,
                      distributorId: _dsfDistributorId.text,
                    );
                  },
            child: const Text('Create DSF'),
          ),
          const SizedBox(height: 16),
          if (_isLoading) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
          if (_status != null) ...[
            const Divider(),
            SelectableText(_status!),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}
