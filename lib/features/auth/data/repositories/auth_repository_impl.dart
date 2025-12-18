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

  AuthRepositoryImpl(
    this._authRemote,
    this._profileRemote,
    this._distributorsRemote,
    this._locationService,
    this._geofencePolicy,
    this._sessionService,
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
    await _sessionService.clear();
    await _authRemote.signOut();
  }
}
