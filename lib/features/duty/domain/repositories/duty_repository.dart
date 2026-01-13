import '../entities/duty_session.dart';
import '../entities/duty_shop_visit.dart';

abstract class DutyRepository {
  Future<String> startDuty({
    required String dsfId,
    required String distributorId,
    required double startLat,
    required double startLng,
  });

  Future<void> endDuty({
    required String dutyId,
    required double endLat,
    required double endLng,
  });

  Future<DutySession> getDuty(String dutyId);

  Future<List<DutyShopVisit>> getShopVisits(String dutyId);
}
