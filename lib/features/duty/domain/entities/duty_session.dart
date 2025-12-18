class DutySession {
  final String id;
  final String dsfId;
  final String distributorId;
  final DateTime startAtUtc;
  final DateTime? endAtUtc;
  final String status;

  const DutySession({
    required this.id,
    required this.dsfId,
    required this.distributorId,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.status,
  });
}
