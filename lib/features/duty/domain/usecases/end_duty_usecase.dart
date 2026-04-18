import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore;

  EndDutyUseCase(
    this._session,
    this._location,
    this._dutyRepository,
    this._tracking,
    this._buildDailyReport,
    this._firestore,
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
    final dutyDateKey =
        (_session.activeDutyDateKey?.trim().isNotEmpty ?? false)
        ? _session.activeDutyDateKey!.trim()
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final pos = await _location.getCurrentPosition();

    await _dutyRepository.endDuty(
      dutyId: dutyId,
      endLat: pos.latitude,
      endLng: pos.longitude,
    );

    Object? trackingError;
    try {
      await _tracking.stop(dutyId: dutyId);
    } catch (e) {
      trackingError = e;
    }

    // Duty must close even if report generation/upload fails.
    await _session.setActiveDutyId(null);
    await _session.setActiveDutyDateKey(null);

    try {
      await _buildDailyReport(
        dutyId: dutyId,
        distributorId: profile.distributorId,
        dsfId: profile.uid,
        dateKey: dutyDateKey,
        upload: uploadReport,
      );
    } catch (_) {
      // Non-blocking: report issues should not keep duty active.
    }

    await _notifyIfShopsMissed(
      profile: profile,
      dutyId: dutyId,
      dutyDateKey: dutyDateKey,
    );

    if (trackingError != null) {
      throw StateError(
        'Duty ended, but tracking cleanup failed: $trackingError',
      );
    }
  }

  Future<void> _notifyIfShopsMissed({
    required SessionUserProfile profile,
    required String dutyId,
    required String dutyDateKey,
  }) async {
    try {
      final dsfAccountId = await _resolveDsfAccountId(profile.uid);
      if (dsfAccountId == null || dsfAccountId.trim().isEmpty) return;

      final assignmentDayKey = _weekdayKeyFromDateKey(dutyDateKey);

      final assignedShopIds = await _loadAssignedShopIds(
        dsfAccountId: dsfAccountId,
        dsfUid: profile.uid,
        assignmentDayKey: assignmentDayKey,
      );
      if (assignedShopIds.isEmpty) return;

      final visits = await _dutyRepository.getShopVisits(dutyId);
      final visitedShopIds = visits
          .map((v) => v.shopId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final missedShopIds =
          assignedShopIds.where((id) => !visitedShopIds.contains(id)).toList()
            ..sort();
      if (missedShopIds.isEmpty) return;

      await _firestore.collection('alerts').add({
        'type': 'shops_missed',
        'dutyId': dutyId,
        'dsfId': profile.uid,
        'distributorId': profile.distributorId,
        'assignmentDayKey': assignmentDayKey,
        'dutyDateKey': dutyDateKey,
        'assignedShops': assignedShopIds.length,
        'visitedShops': visitedShopIds.length,
        'missedShops': missedShopIds.length,
        'missedShopIds': missedShopIds.take(50).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Keep end-duty flow safe even if missed-shop alert logging fails.
    }
  }

  Future<String?> _resolveDsfAccountId(String dsfUid) async {
    final col = _firestore.collection('dsfAccounts');
    final direct = await col.doc(dsfUid).get();
    if (direct.exists) return direct.id;

    final byUid = await col.where('uid', isEqualTo: dsfUid).limit(1).get();
    if (byUid.docs.isNotEmpty) return byUid.docs.first.id;
    return null;
  }

  Future<Set<String>> _loadAssignedShopIds({
    required String dsfAccountId,
    required String dsfUid,
    required String assignmentDayKey,
  }) async {
    final assignedFromDaily = await _firestore
        .collection('seedTsas')
        .doc(dsfAccountId)
        .collection('dailyAssignments')
        .doc(assignmentDayKey)
        .collection('shops')
        .get();

    final dailyIds = assignedFromDaily.docs
        .map((d) => d.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (dailyIds.isNotEmpty) return dailyIds;

    final tsaShopSnap = await _firestore
        .collection('seedTsas')
        .doc(dsfAccountId)
        .collection('shops')
        .get();
    final tsaIds = tsaShopSnap.docs
        .where((doc) => _isScheduledForDay(doc.data(), assignmentDayKey))
        .map((doc) => doc.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (tsaIds.isNotEmpty) return tsaIds;

    final byId = await _firestore
        .collection('shops')
        .where('assignedDsfId', isEqualTo: dsfAccountId)
        .get();
    final byUid = await _firestore
        .collection('shops')
        .where('assignedDsfUid', isEqualTo: dsfUid)
        .get();

    final merged = <String, Map<String, dynamic>>{};
    for (final doc in byId.docs) {
      merged[doc.id] = doc.data();
    }
    for (final doc in byUid.docs) {
      merged[doc.id] = doc.data();
    }

    return merged.entries
        .where((e) => _isScheduledForDay(e.value, assignmentDayKey))
        .map((e) => e.key.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  bool _isScheduledForDay(Map<String, dynamic> data, String dayKey) {
    final schedule = data['schedule'];
    if (schedule is! Map) {
      // Keep backward compatibility for old shops without schedule.
      return true;
    }
    return schedule[dayKey] == true;
  }

  String _weekdayKeyFromDateKey(String? dateKey) {
    DateTime? parsed;
    if (dateKey != null && dateKey.trim().isNotEmpty) {
      parsed = DateTime.tryParse(dateKey.trim());
    }
    final base = parsed ?? DateTime.now();
    switch (base.weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }
}
