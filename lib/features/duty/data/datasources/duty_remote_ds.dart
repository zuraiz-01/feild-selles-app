import 'package:cloud_firestore/cloud_firestore.dart';

class DutyRemoteDataSource {
  final FirebaseFirestore _firestore;

  DutyRemoteDataSource(this._firestore);

  Future<String> startDuty({
    required String dsfId,
    required String distributorId,
    required double startLat,
    required double startLng,
  }) async {
    final doc = await _firestore.collection('duties').add({
      'dsfId': dsfId,
      'distributorId': distributorId,
      'status': 'active',
      'startAt': FieldValue.serverTimestamp(),
      'startLocation': {'lat': startLat, 'lng': startLng},
      'endAt': null,
    });
    return doc.id;
  }

  Future<void> endDuty({
    required String dutyId,
    required double endLat,
    required double endLng,
  }) async {
    await _firestore.collection('duties').doc(dutyId).update({
      'status': 'ended',
      'endAt': FieldValue.serverTimestamp(),
      'endLocation': {'lat': endLat, 'lng': endLng},
    });
  }

  Future<Map<String, dynamic>> getDuty(String dutyId) async {
    final doc = await _firestore.collection('duties').doc(dutyId).get();
    final data = doc.data();
    if (data == null) {
      throw StateError('Duty not found: $dutyId');
    }
    return {'id': doc.id, ...data};
  }

  Future<List<Map<String, dynamic>>> getShopVisits(String dutyId) async {
    final snap = await _firestore
        .collection('duties')
        .doc(dutyId)
        .collection('shopVisits')
        .orderBy('submittedAt', descending: false)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
