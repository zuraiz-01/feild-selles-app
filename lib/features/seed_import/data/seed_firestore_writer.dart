import 'package:cloud_firestore/cloud_firestore.dart';

import 'seed_models.dart';
import 'seed_utils.dart';
import 'excel_seed_parser.dart';

class SeedImportResult {
  final int tsaCount;
  final int shopCount;
  final int saleDocsCount;
  final int distributorCount;
  final int partyCount;
  final int distributorSaleDocsCount;

  const SeedImportResult({
    required this.tsaCount,
    required this.shopCount,
    required this.saleDocsCount,
    required this.distributorCount,
    required this.partyCount,
    required this.distributorSaleDocsCount,
  });
}

class SeedFirestoreWriter {
  final FirebaseFirestore _firestore;

  SeedFirestoreWriter(this._firestore);

  Future<SeedImportResult> write({
    required List<SeedTsaSheet> tsaSheets,
    required List<SeedDistributorSheet> distributorSheets,
    void Function(int completedOps, int totalOps)? onProgress,
  }) async {
    final importId = DateTime.now().toUtc().toIso8601String();
    final importRef = _firestore.collection('seedImports').doc(slugifyId(importId));

    final totalOps = _estimateOps(tsaSheets, distributorSheets) + 1;
    var completedOps = 0;

    Future<void> tick([int inc = 1]) async {
      completedOps += inc;
      onProgress?.call(completedOps, totalOps);
    }

    await importRef.set({
      'status': 'running',
      'startedAt': FieldValue.serverTimestamp(),
      'tsaCount': tsaSheets.length,
      'distributorCount': distributorSheets.length,
    });
    await tick();

    var tsaCount = 0;
    var shopCount = 0;
    var saleDocsCount = 0;
    var distributorCount = 0;
    var partyCount = 0;
    var distributorSaleDocsCount = 0;

    var batch = _firestore.batch();
    var opsInBatch = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (!force && opsInBatch < 450) return;
      if (opsInBatch == 0) return;
      await batch.commit();
      await tick(opsInBatch);
      batch = _firestore.batch();
      opsInBatch = 0;
    }

    void setDoc(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data, {bool merge = true}) {
      batch.set(ref, data, SetOptions(merge: merge));
      opsInBatch++;
    }

    for (final sheet in tsaSheets) {
      final tsaId = slugifyId(sheet.sheetName);
      final tsaRef = _firestore.collection('seedTsas').doc(tsaId);
      setDoc(tsaRef, {
        'type': 'tsa',
        'tsaId': tsaId,
        'name': sheet.tsaName,
        'sheetName': sheet.sheetName,
        'importId': importRef.id,
        'importedAt': FieldValue.serverTimestamp(),
      });
      tsaCount++;
      await commitIfNeeded();

      for (final shop in sheet.shops) {
        final shopId = slugifyId(shop.code);
        final shopRef = tsaRef.collection('shops').doc(shopId);

        setDoc(shopRef, {
          'shopId': shopId,
          'code': shop.code,
          'name': shop.name,
          'area': shop.area,
          if (shop.avg2023 != null) 'avg2023': shop.avg2023,
          if (shop.isFiler != null) 'isFiler': shop.isFiler,
          'tsaId': tsaId,
          'importId': importRef.id,
          'importedAt': FieldValue.serverTimestamp(),
        });
        shopCount++;
        await commitIfNeeded();

        for (final entry in shop.sales.entries) {
          final period = entry.key;
          final value = entry.value;
          final saleRef = shopRef.collection('sales').doc(period.id);
          setDoc(saleRef, {
            'periodId': period.id,
            'label': period.label,
            'kind': period.kind,
            'sortKey': period.sortKey,
            'canola': value.canola,
            'corn': value.corn,
            'total': value.total,
            'tsaId': tsaId,
            'shopId': shopId,
            'importId': importRef.id,
            'importedAt': FieldValue.serverTimestamp(),
          });
          saleDocsCount++;
          await commitIfNeeded();
        }
      }
    }

    for (final sheet in distributorSheets) {
      final distId = slugifyId(sheet.sheetName);
      final distRef = _firestore.collection('seedDistributors').doc(distId);
      setDoc(distRef, {
        'type': 'distributor',
        'distributorId': distId,
        'name': sheet.distributorName,
        'sheetName': sheet.sheetName,
        'importId': importRef.id,
        'importedAt': FieldValue.serverTimestamp(),
      });
      distributorCount++;
      await commitIfNeeded();

      for (final party in sheet.parties) {
        final partyId = slugifyId(party.partyName);
        final partyRef = distRef.collection('parties').doc(partyId);
        setDoc(partyRef, {
          'partyId': partyId,
          'partyName': party.partyName,
          'area': party.area,
          'assignedTo': party.assignedTo,
          'distributorId': distId,
          'importId': importRef.id,
          'importedAt': FieldValue.serverTimestamp(),
        });
        partyCount++;
        await commitIfNeeded();

        for (final entry in party.sales.entries) {
          final period = entry.key;
          final value = entry.value;
          final saleRef = partyRef.collection('sales').doc(period.id);
          setDoc(saleRef, {
            'periodId': period.id,
            'label': period.label,
            'kind': period.kind,
            'sortKey': period.sortKey,
            'canola': value.canola,
            'corn': value.corn,
            'total': value.total,
            'distributorId': distId,
            'partyId': partyId,
            'importId': importRef.id,
            'importedAt': FieldValue.serverTimestamp(),
          });
          distributorSaleDocsCount++;
          await commitIfNeeded();
        }
      }
    }

    await commitIfNeeded(force: true);

    await importRef.set({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'result': {
        'tsaCount': tsaCount,
        'shopCount': shopCount,
        'saleDocsCount': saleDocsCount,
        'distributorCount': distributorCount,
        'partyCount': partyCount,
        'distributorSaleDocsCount': distributorSaleDocsCount,
      },
    }, SetOptions(merge: true));

    return SeedImportResult(
      tsaCount: tsaCount,
      shopCount: shopCount,
      saleDocsCount: saleDocsCount,
      distributorCount: distributorCount,
      partyCount: partyCount,
      distributorSaleDocsCount: distributorSaleDocsCount,
    );
  }

  int _estimateOps(
    List<SeedTsaSheet> tsaSheets,
    List<SeedDistributorSheet> distributorSheets,
  ) {
    var ops = 0;
    for (final sheet in tsaSheets) {
      ops += 1; // tsa doc
      for (final shop in sheet.shops) {
        ops += 1; // shop doc
        ops += shop.sales.length; // sales docs
      }
    }
    for (final sheet in distributorSheets) {
      ops += 1; // distributor doc
      for (final party in sheet.parties) {
        ops += 1; // party doc
        ops += party.sales.length; // sales docs
      }
    }
    return ops;
  }
}

