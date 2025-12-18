import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingRemoteDataSource {
  final FirebaseFirestore _firestore;

  TrackingRemoteDataSource(this._firestore);

  Future<void> upsertSessionSummary({
    required String dutyId,
    required String dsfId,
    required String distributorId,
    required Map<String, dynamic> lastPoint,
  }) async {
    await _firestore.collection('locationSessions').doc(dutyId).set({
      'dutyId': dutyId,
      'dsfId': dsfId,
      'distributorId': distributorId,
      'status': 'active',
      'lastPoint': lastPoint,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addPoint({
    required String dutyId,
    required String dsfId,
    required String distributorId,
    required double lat,
    required double lng,
    required DateTime recordedAtUtc,
  }) async {
    final point = {
      'lat': lat,
      'lng': lng,
      'recordedAt': Timestamp.fromDate(recordedAtUtc),
    };

    await _firestore
        .collection('locationSessions')
        .doc(dutyId)
        .collection('points')
        .add(point);

    await upsertSessionSummary(
      dutyId: dutyId,
      dsfId: dsfId,
      distributorId: distributorId,
      lastPoint: point,
    );
  }

  Future<void> markSessionEnded({required String dutyId}) async {
    await _firestore.collection('locationSessions').doc(dutyId).set({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
