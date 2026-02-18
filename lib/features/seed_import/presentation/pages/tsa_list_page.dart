import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/dsf_account_service.dart';
import '../../data/seed_utils.dart';

class TsaListPage extends StatelessWidget {
  const TsaListPage({super.key});

  Future<void> _createTsa(BuildContext context) async {
    final nameController = TextEditingController();
    final sheetController = TextEditingController();
    String tsaIdPreview = '';

    void recomputeId() {
      final base = sheetController.text.trim().isNotEmpty
          ? sheetController.text
          : nameController.text;
      tsaIdPreview = slugifyId(base);
    }

    final result = await showDialog<_CreateTsaResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create TSA'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'TSA name'),
                    onChanged: (_) => setState(() => recomputeId()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sheetController,
                    decoration: const InputDecoration(
                      labelText: 'Sheet name (optional)',
                    ),
                    onChanged: (_) => setState(() => recomputeId()),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TSA ID: ${tsaIdPreview.isEmpty ? slugifyId('unknown') : tsaIdPreview}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final sheetName = sheetController.text.trim();
                    if (name.isEmpty) return;
                    final base = sheetName.isNotEmpty ? sheetName : name;
                    final id = slugifyId(base);
                    Navigator.of(context).pop(
                      _CreateTsaResult(
                        tsaId: id,
                        name: name,
                        sheetName: sheetName,
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    final col = FirebaseFirestore.instance.collection('seedTsas');
    final ref = col.doc(result.tsaId);
    final existing = await ref.get();
    if (existing.exists) {
      Get.snackbar(
        'TSA already exists',
        'A TSA with id "${result.tsaId}" already exists.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await ref.set({
      'type': 'tsa',
      'tsaId': result.tsaId,
      'name': result.name,
      if (result.sheetName.isNotEmpty) 'sheetName': result.sheetName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Get.snackbar(
      'TSA created',
      result.name,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _deleteDocsByQuery(Query<Map<String, dynamic>> query) async {
    const batchSize = 300;
    final firestore = FirebaseFirestore.instance;

    while (true) {
      final snap = await query.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _deleteShopSalesAndShops(
    FirebaseFirestore firestore,
    String tsaId,
  ) async {
    final shopsCol = firestore
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops');
    final shopsSnap = await shopsCol.get();
    for (final shopDoc in shopsSnap.docs) {
      await _deleteDocsByQuery(shopDoc.reference.collection('sales'));
      await shopDoc.reference.delete();
    }
  }

  Future<void> _deleteDailyAssignments(
    FirebaseFirestore firestore,
    String tsaId,
  ) async {
    final dailyCol = firestore
        .collection('seedTsas')
        .doc(tsaId)
        .collection('dailyAssignments');
    final daySnap = await dailyCol.get();
    for (final dayDoc in daySnap.docs) {
      await _deleteDocsByQuery(dayDoc.reference.collection('shops'));
      await dayDoc.reference.delete();
    }
  }

  Future<void> _deleteDutiesAndVisitsForDsf(
    FirebaseFirestore firestore,
    String dsfId,
  ) async {
    final dutiesSnap = await firestore
        .collection('duties')
        .where('dsfId', isEqualTo: dsfId)
        .get();
    for (final dutyDoc in dutiesSnap.docs) {
      await _deleteDocsByQuery(dutyDoc.reference.collection('shopVisits'));
      await dutyDoc.reference.delete();
    }
  }

  Future<void> _deleteLocationSessionsForDsf(
    FirebaseFirestore firestore,
    String dsfId,
  ) async {
    final sessionsSnap = await firestore
        .collection('locationSessions')
        .where('dsfId', isEqualTo: dsfId)
        .get();
    for (final sessionDoc in sessionsSnap.docs) {
      await _deleteDocsByQuery(sessionDoc.reference.collection('points'));
      await sessionDoc.reference.delete();
    }
  }

  Future<void> _deleteShopVisitsForTsaWithoutCollectionGroupIndex(
    FirebaseFirestore firestore,
    String tsaId,
  ) async {
    final targetTsaId = tsaId.trim();
    if (targetTsaId.isEmpty) return;

    final refsToDelete = <DocumentReference<Map<String, dynamic>>>[];
    final dutiesSnap = await firestore.collection('duties').get();

    for (final dutyDoc in dutiesSnap.docs) {
      final visitsSnap = await dutyDoc.reference.collection('shopVisits').get();
      for (final visitDoc in visitsSnap.docs) {
        final visitTsaId = ((visitDoc.data()['tsaId'] as String?) ?? '').trim();
        if (visitTsaId == targetTsaId) {
          refsToDelete.add(visitDoc.reference);
        }
      }
    }

    var batch = firestore.batch();
    var opsInBatch = 0;
    for (final ref in refsToDelete) {
      batch.delete(ref);
      opsInBatch++;
      if (opsInBatch >= 450) {
        await batch.commit();
        batch = firestore.batch();
        opsInBatch = 0;
      }
    }
    if (opsInBatch > 0) {
      await batch.commit();
    }
  }

  Future<void> _deleteTsaEverywhere(String tsaId) async {
    final firestore = FirebaseFirestore.instance;

    final dsfIdsToPurge = <String>{tsaId};
    final dsfAccountRefs = <DocumentReference<Map<String, dynamic>>>{};

    final directDsfRef = firestore.collection('dsfAccounts').doc(tsaId);
    final directDsfSnap = await directDsfRef.get();
    if (directDsfSnap.exists) {
      dsfAccountRefs.add(directDsfRef);
      final uid = (directDsfSnap.data()?['uid'] as String?)?.trim();
      if (uid != null && uid.isNotEmpty) {
        dsfIdsToPurge.add(uid);
      }
    }

    final byTsaSnap = await firestore
        .collection('dsfAccounts')
        .where('tsaId', isEqualTo: tsaId)
        .get();
    for (final doc in byTsaSnap.docs) {
      dsfAccountRefs.add(doc.reference);
      final docId = doc.id.trim();
      if (docId.isNotEmpty) dsfIdsToPurge.add(docId);
      final uid = (doc.data()['uid'] as String?)?.trim();
      if (uid != null && uid.isNotEmpty) dsfIdsToPurge.add(uid);
    }

    final accountService = DsfAccountService(firestore);
    for (final accountRef in dsfAccountRefs) {
      try {
        await accountService.deleteAccount(tsaId: accountRef.id);
      } catch (_) {
        // Continue cascading cleanup even if auth deletion fails.
      }
      await accountRef.delete();
    }

    for (final dsfId in dsfIdsToPurge) {
      await firestore.collection('users').doc(dsfId).delete();
      await _deleteDutiesAndVisitsForDsf(firestore, dsfId);
      await _deleteLocationSessionsForDsf(firestore, dsfId);
      await _deleteDocsByQuery(
        firestore.collection('alerts').where('dsfId', isEqualTo: dsfId),
      );
      await _deleteDocsByQuery(
        firestore.collection('shops').where('assignedDsfId', isEqualTo: dsfId),
      );
      await _deleteDocsByQuery(
        firestore.collection('shops').where('assignedDsfUid', isEqualTo: dsfId),
      );
      await _deleteDocsByQuery(
        firestore.collection('reportFiles').where('dsfId', isEqualTo: dsfId),
      );
    }

    await _deleteShopVisitsForTsaWithoutCollectionGroupIndex(firestore, tsaId);

    await _deleteShopSalesAndShops(firestore, tsaId);
    await _deleteDailyAssignments(firestore, tsaId);

    await firestore.collection('seedTsas').doc(tsaId).delete();
    await firestore.collection('distributors').doc(tsaId).delete();
  }

  void _goToAdminDashboard() {
    Get.offAllNamed(AppRoutes.adminDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final col = FirebaseFirestore.instance.collection('seedTsas');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goToAdminDashboard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _goToAdminDashboard,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to dashboard',
          ),
          titleSpacing: 20,
          toolbarHeight: 70,
          title: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.warmSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TSAs',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Seeded accounts',
                    style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => authController.logout(),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createTsa(context),
          child: const Icon(Icons.add),
        ),
        body: AppShell(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: col.orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No TSA data. Import Excel first.'),
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = (data['name'] as String?) ?? doc.id;
                  final sheetName = (data['sheetName'] as String?) ?? '';

                  return GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.skySoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person, color: AppTheme.sky),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (sheetName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  sheetName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete TSA'),
                                content: Text(
                                  'Delete "$name" completely?\n\n'
                                  'This removes TSA, DSF account, shops, assignments, duties, alerts, and related records.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete All'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;

                            try {
                              await _deleteTsaEverywhere(doc.id);
                              if (!context.mounted) return;
                              Get.snackbar(
                                'Deleted',
                                'TSA "$name" and all related data removed.',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              Get.snackbar(
                                'Delete failed',
                                e.toString(),
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                        ),
                        IconButton(
                          onPressed: () => Get.toNamed(
                            AppRoutes.seedTsaAccount,
                            arguments: {'tsaId': doc.id, 'tsaName': name},
                          ),
                          icon: const Icon(Icons.arrow_forward_ios, size: 18),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreateTsaResult {
  final String tsaId;
  final String name;
  final String sheetName;

  const _CreateTsaResult({
    required this.tsaId,
    required this.name,
    required this.sheetName,
  });
}
