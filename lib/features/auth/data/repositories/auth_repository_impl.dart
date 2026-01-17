import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/domain/services/geofence_policy.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../distributors/data/datasources/distributors_remote_ds.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_ds.dart';
import '../datasources/user_profile_remote_ds.dart';
import '../../../../core/services/session/session_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authRemote;
  final UserProfileRemoteDataSource _profileRemote;
  final DistributorsRemoteDataSource _distributorsRemote;
  final LocationService _locationService;
  final GeofencePolicy _geofencePolicy;
  final SessionService _sessionService;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl(
    this._authRemote,
    this._profileRemote,
    this._distributorsRemote,
    this._locationService,
    this._geofencePolicy,
    this._sessionService,
    this._firestore,
  );

  @override
  Future<UserProfile> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _authRemote.signInWithEmailPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw StateError('Auth failed: missing uid');
    }

    final profileModel = await _profileRemote.getUserProfile(uid);
    final claimedRole = profileModel.roleAsEnum();

    final effectiveRole = await _resolveEffectiveRole(
      uid: uid,
      claimedRole: claimedRole,
    );

    if (effectiveRole == UserRole.dsf) {
      await _enforceOfficeGeofence(distributorId: profileModel.distributorId);
      await _logAdminEvent(
        type: 'dsf_login',
        dsfId: uid,
        distributorId: profileModel.distributorId,
        locationLabel: 'at office',
      );
    }

    return profileModel.toEntity(effectiveRole: effectiveRole);
  }

  @override
  Future<UserProfile?> loadCurrentSessionProfile() async {
    final uid = _authRemote.currentUid;
    if (uid == null) {
      return null;
    }

    final profileModel = await _profileRemote.getUserProfile(uid);
    final claimedRole = profileModel.roleAsEnum();
    final effectiveRole = await _resolveEffectiveRole(
      uid: uid,
      claimedRole: claimedRole,
    );
    return profileModel.toEntity(effectiveRole: effectiveRole);
  }

  Future<UserRole> _resolveEffectiveRole({
    required String uid,
    required UserRole claimedRole,
  }) async {
    if (claimedRole != UserRole.admin) {
      return claimedRole;
    }

    final isAllowlisted = await _profileRemote.isAdminUid(uid);
    if (!isAllowlisted) {
      throw StateError('Admin access denied');
    }

    return UserRole.admin;
  }

  Future<void> _enforceOfficeGeofence({required String distributorId}) async {
    final office = await _distributorsRemote.getOfficeGeofence(distributorId);
    final Position pos = await _locationService.getCurrentPosition();

    final decision = _geofencePolicy.validateOffice(
      office: office,
      currentLat: pos.latitude,
      currentLng: pos.longitude,
    );

    if (!decision.allowed) {
      throw StateError(
        'Login allowed only inside office. Distance: ${decision.distanceMeters.toStringAsFixed(0)}m',
      );
    }
  }

  @override
  Future<void> logout() async {
    final profile = _sessionService.profile;
    if (profile?.role == UserRole.dsf &&
        _sessionService.activeDutyId != null) {
      throw StateError('End duty before logout');
    }
    if (profile?.role == UserRole.dsf && profile != null) {
      await _logDsfLogout(profile);
    }
    await _sessionService.clear();
    await _authRemote.signOut();
  }

  Future<void> _logDsfLogout(SessionUserProfile profile) async {
    double? lat;
    double? lng;
    try {
      final Position pos = await _locationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // ignore location failures for logout logging
    }
    await _logAdminEvent(
      type: 'dsf_logout',
      dsfId: profile.uid,
      distributorId: profile.distributorId,
      lat: lat,
      lng: lng,
    );
  }

  Future<void> _logAdminEvent({
    required String type,
    required String dsfId,
    required String distributorId,
    String? locationLabel,
    double? lat,
    double? lng,
  }) async {
    try {
      await _firestore.collection('alerts').add({
        'type': type,
        'dsfId': dsfId,
        'distributorId': distributorId,
        if (locationLabel != null) 'locationLabel': locationLabel,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore logging failures
    }
  }
}
