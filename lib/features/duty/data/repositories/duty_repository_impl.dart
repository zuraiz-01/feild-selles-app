import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/duty_session.dart';
import '../../domain/entities/duty_shop_visit.dart';
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

  @override
  Future<List<DutyShopVisit>> getShopVisits(String dutyId) async {
    final maps = await _remote.getShopVisits(dutyId);
    return maps.map(_mapVisit).toList();
  }

  DutyShopVisit _mapVisit(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final id = map['id'] as String? ?? '';
    final dutyId = map['dutyId'] as String? ?? '';
    final dsfId = map['dsfId'] as String? ?? '';
    final distributorId = map['distributorId'] as String? ?? '';
    final tsaId = map['tsaId'] as String? ?? '';
    final shopId = map['shopId'] as String? ?? id;
    final shopTitle = map['shopTitle'] as String? ?? shopId;

    final submittedLocation = map['submittedLocation'];
    double? submittedLat;
    double? submittedLng;
    if (submittedLocation is Map) {
      submittedLat = parseDouble(submittedLocation['lat']);
      submittedLng = parseDouble(submittedLocation['lng']);
    }

    return DutyShopVisit(
      id: id,
      dutyId: dutyId,
      dsfId: dsfId,
      distributorId: distributorId,
      tsaId: tsaId,
      shopId: shopId,
      shopTitle: shopTitle,
      stock: parseDouble(map['stock']),
      payment: parseDouble(map['payment']),
      distanceMeters: parseDouble(map['distanceMeters']),
      submittedLat: submittedLat,
      submittedLng: submittedLng,
      visitStartedAt: parseDate(map['visitStartedAt']),
      submittedAt: parseDate(map['submittedAt']),
      notes: (map['notes'] as String?) ?? '',
    );
  }
}
