import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
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
  final _dsfOfficeLat = TextEditingController();
  final _dsfOfficeLng = TextEditingController();
  final _dsfOfficeRadius = TextEditingController(text: '250');

  bool _isLoading = false;
  String? _status;
  bool _showAdminPassword = false;
  bool _showDsfPassword = false;

  bool get _enabled => kDebugMode || _bootstrapSecret.isNotEmpty;

  @override
  void dispose() {
    _adminEmail.dispose();
    _adminPassword.dispose();
    _adminDistributorId.dispose();
    _dsfEmail.dispose();
    _dsfPassword.dispose();
    _dsfDistributorId.dispose();
    _dsfOfficeLat.dispose();
    _dsfOfficeLng.dispose();
    _dsfOfficeRadius.dispose();
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
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
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
          officeLat: officeLat,
          officeLng: officeLng,
          officeRadiusMeters: officeRadiusMeters,
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
      } else if (role == UserRole.dsf) {
        await _ensureDistributorDoc(
          firestore: firestore,
          distributorId: distributorId.trim(),
          name: email.trim(),
          officeLat: officeLat,
          officeLng: officeLng,
          officeRadiusMeters: officeRadiusMeters,
        );
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
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
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
      } else if (role == UserRole.dsf) {
        await _ensureDistributorDocViaRest(
          idToken: idToken,
          distributorId: trimmedDistributorId,
          name: trimmedEmail,
          officeLat: officeLat,
          officeLng: officeLng,
          officeRadiusMeters: officeRadiusMeters,
          projectId: projectId,
        );
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

  Future<void> _ensureDistributorDoc({
    required FirebaseFirestore firestore,
    required String distributorId,
    required String name,
    double? officeLat,
    double? officeLng,
    double? officeRadiusMeters,
  }) async {
    if (officeLat == null || officeLng == null || officeRadiusMeters == null) {
      throw StateError('Office geofence (lat/lng/radius) is required.');
    }
    await firestore.collection('distributors').doc(distributorId).set({
      'name': name,
      'distributorId': distributorId,
      'officeGeofence': {
        'center': {'lat': officeLat, 'lng': officeLng},
        'radiusMeters': officeRadiusMeters,
      },
    }, SetOptions(merge: true));
  }

  Future<void> _ensureDistributorDocViaRest({
    required String idToken,
    required String distributorId,
    required String name,
    required double? officeLat,
    required double? officeLng,
    required double? officeRadiusMeters,
    required String projectId,
  }) async {
    if (officeLat == null || officeLng == null || officeRadiusMeters == null) {
      throw StateError('Office geofence (lat/lng/radius) is required.');
    }
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/distributors/$distributorId',
    );
    final res = await http.patch(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'fields': {
          'name': {'stringValue': name},
          'distributorId': {'stringValue': distributorId},
          'officeGeofence': {
            'mapValue': {
              'fields': {
                'center': {
                  'mapValue': {
                    'fields': {
                      'lat': {'doubleValue': officeLat},
                      'lng': {'doubleValue': officeLng},
                    },
                  },
                },
                'radiusMeters': {'doubleValue': officeRadiusMeters},
              },
            },
          },
        },
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('REST write distributors/$distributorId failed: ${res.body}');
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
      body: AppShell(
        child: ListView(
          children: [
            const SectionTitle(
              title: 'Bootstrap accounts',
              subtitle:
                  'Creates Auth users + profile documents for Admin and DSF roles.',
            ),
            const SizedBox(height: 12),
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Note: On some Android emulators, email/password sign-up may fail due to reCAPTCHA config.\nThis screen auto-falls back to a REST bootstrap when needed.',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
                ),
              ),
              const SizedBox(height: 12),
            ],
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('Admin'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminPassword,
                    obscureText: !_showAdminPassword,
                    decoration: InputDecoration(
                      labelText: 'Admin password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showAdminPassword = !_showAdminPassword;
                          });
                        },
                        icon: Icon(
                          _showAdminPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminDistributorId,
                    decoration: const InputDecoration(
                      labelText: 'Admin distributorId (any string)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('DSF'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dsfEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'DSF email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dsfPassword,
                    obscureText: !_showDsfPassword,
                    decoration: InputDecoration(
                      labelText: 'DSF password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showDsfPassword = !_showDsfPassword;
                          });
                        },
                        icon: Icon(
                          _showDsfPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dsfDistributorId,
                    decoration: const InputDecoration(
                      labelText: 'DSF distributorId (must exist in Firestore)',
                      hintText: 'e.g. distributor_karachi_01',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dsfOfficeLat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Office latitude',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dsfOfficeLng,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Office longitude',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dsfOfficeRadius,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Office radius (meters)',
                      prefixIcon: Icon(Icons.circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            final officeLat =
                                double.tryParse(_dsfOfficeLat.text.trim());
                            final officeLng =
                                double.tryParse(_dsfOfficeLng.text.trim());
                            final officeRadius =
                                double.tryParse(_dsfOfficeRadius.text.trim());
                            if (officeLat == null ||
                                officeLng == null ||
                                officeRadius == null) {
                              setState(() {
                                _status =
                                    'Office geofence (lat/lng/radius) is required.';
                              });
                              return;
                            }
                            _createAccount(
                              role: UserRole.dsf,
                              email: _dsfEmail.text,
                              password: _dsfPassword.text,
                              distributorId: _dsfDistributorId.text,
                              officeLat: officeLat,
                              officeLng: officeLng,
                              officeRadiusMeters: officeRadius,
                            );
                          },
                    child: const Text('Create DSF'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ],
            if (_status != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_status!),
              ),
            ],
          ],
        ),
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
