import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/domain/services/geofence_policy.dart';

class DistributorsRemoteDataSource {
  final FirebaseFirestore _firestore;

  DistributorsRemoteDataSource(this._firestore);

  Future<OfficeGeofence> getOfficeGeofence(String distributorId) async {
    final doc = await _firestore
        .collection('distributors')
        .doc(distributorId)
        .get();
    final data = doc.data();
    if (data == null) {
      throw StateError('Distributor not found: $distributorId');
    }

    final office = data['officeGeofence'];
    if (office is! Map<String, dynamic>) {
      throw StateError(
        'officeGeofence missing for distributor: $distributorId',
      );
    }

    final center = office['center'];
    final radiusMeters = office['radiusMeters'];
    if (center is! Map<String, dynamic> || radiusMeters is! num) {
      throw StateError(
        'Invalid officeGeofence schema for distributor: $distributorId',
      );
    }

    final lat = center['lat'];
    final lng = center['lng'];
    if (lat is! num || lng is! num) {
      throw StateError(
        'Invalid officeGeofence center for distributor: $distributorId',
      );
    }

    return OfficeGeofence(
      centerLat: lat.toDouble(),
      centerLng: lng.toDouble(),
      radiusMeters: radiusMeters.toDouble(),
    );
  }
}
