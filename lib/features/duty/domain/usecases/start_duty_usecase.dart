import 'package:intl/intl.dart';

import '../../../../core/domain/services/geofence_policy.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../distributors/data/datasources/distributors_remote_ds.dart';
import '../../domain/repositories/duty_repository.dart';
import '../../../../core/services/location/background_tracking_service.dart';

class StartDutyResult {
  final String dutyId;
  final String dateKey;

  const StartDutyResult({required this.dutyId, required this.dateKey});
}

class StartDutyUseCase {
  final SessionService _session;
  final LocationService _location;
  final GeofencePolicy _geofence;
  final DistributorsRemoteDataSource _distributors;
  final DutyRepository _dutyRepository;
  final BackgroundTrackingService _tracking;

  StartDutyUseCase(
    this._session,
    this._location,
    this._geofence,
    this._distributors,
    this._dutyRepository,
    this._tracking,
  );

  Future<StartDutyResult> call() async {
    final profile = _session.profile;
    if (profile == null) {
      throw StateError('Not logged in');
    }
    if (profile.role != UserRole.dsf) {
      throw StateError('Only DSF can start duty');
    }
    if (_session.activeDutyId != null) {
      throw StateError('Duty already active');
    }

    final office = await _distributors.getOfficeGeofence(profile.distributorId);
    final pos = await _location.getCurrentPosition();
    final decision = _geofence.validateOffice(
      office: office,
      currentLat: pos.latitude,
      currentLng: pos.longitude,
    );
    if (!decision.allowed) {
      throw StateError('Start duty allowed only inside office');
    }

    final dutyId = await _dutyRepository.startDuty(
      dsfId: profile.uid,
      distributorId: profile.distributorId,
      startLat: pos.latitude,
      startLng: pos.longitude,
    );

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _session.setActiveDutyId(dutyId);
    await _session.setActiveDutyDateKey(dateKey);

    await _tracking.start(dutyId: dutyId);
    return StartDutyResult(dutyId: dutyId, dateKey: dateKey);
  }
}
