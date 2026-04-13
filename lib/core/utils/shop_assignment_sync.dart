import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> shopScheduleDays = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

Map<String, bool> normalizeShopSchedule(Map? rawSchedule) {
  return Map<String, bool>.fromEntries(
    shopScheduleDays.map((day) => MapEntry(day, rawSchedule?[day] == true)),
  );
}

Future<void> syncShopTsaAssignment({
  required FirebaseFirestore firestore,
  required String shopId,
  required String? previousTsaId,
  required Map<String, bool>? previousSchedule,
  required String? nextTsaId,
  required Map<String, bool> nextSchedule,
  required Map<String, dynamic>? nextTsaShopData,
  String? nextTsaName,
}) async {
  final prevId = previousTsaId?.trim() ?? '';
  final nextId = nextTsaId?.trim() ?? '';
  final normalizedPrev = previousSchedule == null
      ? {for (final day in shopScheduleDays) day: true}
      : normalizeShopSchedule(previousSchedule);
  final normalizedNext = normalizeShopSchedule(nextSchedule);

  WriteBatch batch = firestore.batch();
  var ops = 0;

  Future<void> flushIfNeeded() async {
    if (ops < 450) return;
    await batch.commit();
    batch = firestore.batch();
    ops = 0;
  }

  Future<void> queueDelete(DocumentReference ref) async {
    batch.delete(ref);
    ops++;
    await flushIfNeeded();
  }

  Future<void> queueSet(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    batch.set(ref, data, SetOptions(merge: true));
    ops++;
    await flushIfNeeded();
  }

  Future<void> syncAssignmentDays({
    required String tsaId,
    required Map<String, bool> schedule,
    required bool deleteShopDoc,
  }) async {
    final tsaRef = firestore.collection('seedTsas').doc(tsaId);
    for (final day in shopScheduleDays) {
      final dayRef = tsaRef
          .collection('dailyAssignments')
          .doc(day)
          .collection('shops')
          .doc(shopId);
      if (schedule[day] == true) {
        await queueSet(dayRef, {'assignedAt': FieldValue.serverTimestamp()});
      } else {
        await queueDelete(dayRef);
      }
    }
    if (deleteShopDoc) {
      await queueDelete(tsaRef.collection('shops').doc(shopId));
    }
  }

  if (prevId.isNotEmpty) {
    await syncAssignmentDays(
      tsaId: prevId,
      schedule: normalizedPrev,
      deleteShopDoc: prevId != nextId || nextId.isEmpty,
    );
  }

  if (nextId.isNotEmpty) {
    if (nextTsaShopData == null) {
      throw ArgumentError(
        'nextTsaShopData is required when nextTsaId is provided.',
      );
    }

    final tsaRef = firestore.collection('seedTsas').doc(nextId);
    final tsaPayload = <String, dynamic>{
      'type': 'tsa',
      'tsaId': nextId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final trimmedName = nextTsaName?.trim() ?? '';
    if (trimmedName.isNotEmpty) {
      tsaPayload['name'] = trimmedName;
    }
    await queueSet(tsaRef, tsaPayload);
    await queueSet(tsaRef.collection('shops').doc(shopId), nextTsaShopData);

    for (final day in shopScheduleDays) {
      final dayRef = tsaRef
          .collection('dailyAssignments')
          .doc(day)
          .collection('shops')
          .doc(shopId);
      if (normalizedNext[day] == true) {
        await queueSet(dayRef, {'assignedAt': FieldValue.serverTimestamp()});
      } else {
        await queueDelete(dayRef);
      }
    }
  }

  if (ops > 0) {
    await batch.commit();
  }
}
