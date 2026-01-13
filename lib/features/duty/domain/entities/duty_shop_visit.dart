class DutyShopVisit {
  final String id;
  final String dutyId;
  final String dsfId;
  final String distributorId;
  final String tsaId;
  final String shopId;
  final String shopTitle;
  final double? stock;
  final double? payment;
  final double? distanceMeters;
  final double? submittedLat;
  final double? submittedLng;
  final DateTime? visitStartedAt;
  final DateTime? submittedAt;
  final String notes;

  const DutyShopVisit({
    required this.id,
    required this.dutyId,
    required this.dsfId,
    required this.distributorId,
    required this.tsaId,
    required this.shopId,
    required this.shopTitle,
    required this.stock,
    required this.payment,
    required this.distanceMeters,
    required this.submittedLat,
    required this.submittedLng,
    required this.visitStartedAt,
    required this.submittedAt,
    required this.notes,
  });
}
