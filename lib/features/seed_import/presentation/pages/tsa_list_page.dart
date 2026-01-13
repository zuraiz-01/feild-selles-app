import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final col = FirebaseFirestore.instance.collection('seedTsas');

    return Scaffold(
      appBar: AppBar(
        title: const Text('TSAs'),
        actions: [
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
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
