import '../../utils/geo_utils.dart';

class OfficeGeofence {
  final double centerLat;
  final double centerLng;
  final double radiusMeters;

  const OfficeGeofence({
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
  });
}

class GeofenceDecision {
  final bool allowed;
  final double distanceMeters;

  const GeofenceDecision({required this.allowed, required this.distanceMeters});
}

class GeofencePolicy {
  GeofenceDecision validateOffice({
    required OfficeGeofence office,
    required double currentLat,
    required double currentLng,
  }) {
    final distance = GeoUtils.distanceMeters(
      lat1: currentLat,
      lng1: currentLng,
      lat2: office.centerLat,
      lng2: office.centerLng,
    );

    return GeofenceDecision(
      allowed: distance <= office.radiusMeters,
      distanceMeters: distance,
    );
  }
}
