import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/duty_session.dart';
import '../../domain/repositories/duty_repository.dart';
import '../datasources/duty_remote_ds.dart';

class DutyRepositoryImpl implements DutyRepository {
  final DutyRemoteDataSource _remote;

  DutyRepositoryImpl(this._remote);

  @override
  Future<String> startDuty({
    required String dsfId,
    required String distributorId,
    required double startLat,
    required double startLng,
  }) {
    return _remote.startDuty(
      dsfId: dsfId,
      distributorId: distributorId,
      startLat: startLat,
      startLng: startLng,
    );
  }

  @override
  Future<void> endDuty({
    required String dutyId,
    required double endLat,
    required double endLng,
  }) {
    return _remote.endDuty(dutyId: dutyId, endLat: endLat, endLng: endLng);
  }

  @override
  Future<DutySession> getDuty(String dutyId) async {
    final map = await _remote.getDuty(dutyId);

    final dsfId = map['dsfId'];
    final distributorId = map['distributorId'];
    final status = map['status'];
    final startAt = map['startAt'];
    final endAt = map['endAt'];

    if (dsfId is! String || distributorId is! String || status is! String) {
      throw StateError('Invalid duty schema: $dutyId');
    }

    DateTime startAtUtc;
    if (startAt is Timestamp) {
      startAtUtc = startAt.toDate().toUtc();
    } else {
      startAtUtc = DateTime.now().toUtc();
    }

    DateTime? endAtUtc;
    if (endAt is Timestamp) {
      endAtUtc = endAt.toDate().toUtc();
    }

    return DutySession(
      id: dutyId,
      dsfId: dsfId,
      distributorId: distributorId,
      startAtUtc: startAtUtc,
      endAtUtc: endAtUtc,
      status: status,
    );
  }
}
