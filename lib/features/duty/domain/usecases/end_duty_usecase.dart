import 'package:intl/intl.dart';

import '../../../../core/models/user_role.dart';
import '../../../../core/services/location/background_tracking_service.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../reports/domain/usecases/build_daily_report_usecase.dart';
import '../../domain/repositories/duty_repository.dart';

class EndDutyUseCase {
  final SessionService _session;
  final LocationService _location;
  final DutyRepository _dutyRepository;
  final BackgroundTrackingService _tracking;
  final BuildDailyReportUseCase _buildDailyReport;

  EndDutyUseCase(
    this._session,
    this._location,
    this._dutyRepository,
    this._tracking,
    this._buildDailyReport,
  );

  Future<void> call({required bool uploadReport}) async {
    final profile = _session.profile;
    if (profile == null) {
      throw StateError('Not logged in');
    }
    if (profile.role != UserRole.dsf) {
      throw StateError('Only DSF can end duty');
    }

    final dutyId = _session.activeDutyId;
    if (dutyId == null) {
      throw StateError('No active duty');
    }

    final pos = await _location.getCurrentPosition();

    await _dutyRepository.endDuty(
      dutyId: dutyId,
      endLat: pos.latitude,
      endLng: pos.longitude,
    );

    await _tracking.stop(dutyId: dutyId);

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _buildDailyReport(
      dutyId: dutyId,
      distributorId: profile.distributorId,
      dsfId: profile.uid,
      dateKey: dateKey,
      upload: uploadReport,
    );

    await _session.setActiveDutyId(null);
  }
}
