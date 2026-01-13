import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../core/services/session/session_service.dart';

class ShopsToVisitPage extends StatelessWidget {
  const ShopsToVisitPage({super.key});

  Future<String?> _loadTsaId(String uid) async {
    final query = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = doc.data();
    final tsaId = data['tsaId'];
    if (tsaId is String && tsaId.trim().isNotEmpty) {
      return tsaId;
    }
    return doc.id;
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final profile = session.profile;
    final dateKey = session.activeDutyDateKey;

    return Scaffold(
      appBar: AppBar(title: const Text('Shops to Visit')),
      body: AppShell(
        child: profile == null
            ? const Center(child: Text('Session missing. Please login again.'))
            : (dateKey == null || dateKey.trim().isEmpty)
            ? const Center(child: Text('No active duty day. Start duty first.'))
            : FutureBuilder<String?>(
                future: _loadTsaId(profile.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Failed to load assigned shops.'),
                    );
                  }
                  final tsaId = snapshot.data;
                  if (tsaId == null || tsaId.trim().isEmpty) {
                    return const Center(
                      child: Text('No TSA assigned to this DSF account.'),
                    );
                  }
                  final shopsCol = FirebaseFirestore.instance
                      .collection('seedTsas')
                      .doc(tsaId)
                      .collection('shops');
                  final assignmentCol = FirebaseFirestore.instance
                      .collection('seedTsas')
                      .doc(tsaId)
                      .collection('dailyAssignments')
                      .doc(dateKey)
                      .collection('shops');
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: assignmentCol.snapshots(),
                    builder: (context, assignedSnap) {
                      if (assignedSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (assignedSnap.hasError) {
                        return const Center(
                          child: Text('Unable to load assigned shops.'),
                        );
                      }
                      final assignedIds =
                          assignedSnap.data?.docs.map((d) => d.id).toSet() ??
                          <String>{};
                      if (assignedIds.isEmpty) {
                        return Center(
                          child: Text(
                            'No shops assigned for $dateKey.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: shopsCol.orderBy('code').snapshots(),
                        builder: (context, shopSnap) {
                          if (shopSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (shopSnap.hasError) {
                            return const Center(
                              child: Text('Unable to load shops.'),
                            );
                          }
                          final all = shopSnap.data?.docs ?? const [];
                          final docs = all
                              .where((d) => assignedIds.contains(d.id))
                              .toList();
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text('No shops found for this day.'),
                            );
                          }
                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final code = (data['code'] as String?) ?? '';
                              final name = (data['name'] as String?) ?? '';
                              final area = (data['area'] as String?) ?? '';
                              final title = name.isEmpty
                                  ? doc.id
                                  : '$name (${code.trim()})';
                              return GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  subtitle: area.isEmpty
                                      ? null
                                      : Text(
                                          area,
                                          style: const TextStyle(
                                            color: AppTheme.mutedInk,
                                          ),
                                        ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Get.toNamed(
                                    AppRoutes.dsfShopVisit,
                                    arguments: {
                                      'tsaId': tsaId,
                                      'shopId': doc.id,
                                      'shopTitle': name.isEmpty ? doc.id : name,
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
