import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../core/services/session/session_service.dart';

class ShopsToVisitPage extends StatelessWidget {
  const ShopsToVisitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final profile = session.profile;
    final dateKey = session.activeDutyDateKey;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Session missing. Please login again.')),
      );
    }
    if (dateKey == null || dateKey.trim().isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No active duty day. Start duty first.')),
      );
    }

    final assignments = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(profile.uid)
        .collection('dailyAssignments')
        .doc(dateKey)
        .collection('shops')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text('Shops for $dateKey')),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: assignments,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              final fallbackShops = FirebaseFirestore.instance
                  .collection('seedTsas')
                  .doc(profile.uid)
                  .collection('shops')
                  .orderBy('code')
                  .snapshots();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No daily assignment found for $dateKey.\nShowing TSA shops, then globally assigned shops.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: fallbackShops,
                      builder: (context, shopsSnap) {
                        if (shopsSnap.hasError) {
                          return Center(
                            child: Text(shopsSnap.error.toString()),
                          );
                        }
                        if (!shopsSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final shopDocs = shopsSnap.data!.docs;
                        if (shopDocs.isNotEmpty) {
                          return _buildShopList(context, profile.uid, shopDocs);
                        }
                        return FutureBuilder<List<String>>(
                          future: _resolveDsfIds(),
                          builder: (context, idsSnap) {
                            if (idsSnap.hasError) {
                              return Center(
                                child: Text(idsSnap.error.toString()),
                              );
                            }
                            if (!idsSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final ids = idsSnap.data!;
                            if (ids.isEmpty) {
                              return const Center(
                                child: Text('No shops found.'),
                              );
                            }
                            final fallbackAssigned = FirebaseFirestore.instance
                                .collection('shops')
                                .where('assignedDsfId', whereIn: ids)
                                .snapshots();
                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: fallbackAssigned,
                              builder: (context, assignedSnap) {
                                if (assignedSnap.hasError) {
                                  return Center(
                                    child: Text(assignedSnap.error.toString()),
                                  );
                                }
                                if (!assignedSnap.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final assignedDocs = assignedSnap.data!.docs;
                                if (assignedDocs.isEmpty) {
                                  return const Center(
                                    child: Text('No shops found.'),
                                  );
                                }
                                return _buildShopList(
                                  context,
                                  '',
                                  assignedDocs,
                                  useGlobal: true,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final assign = docs[index];
                final shopRef = FirebaseFirestore.instance
                    .collection('seedTsas')
                    .doc(profile.uid)
                    .collection('shops')
                    .doc(assign.id);
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: shopRef.snapshots(),
                  builder: (context, shopSnap) {
                    if (shopSnap.hasError) {
                      return GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error loading shop ${assign.id}'),
                      );
                    }
                    if (!shopSnap.hasData || !shopSnap.data!.exists) {
                      return GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Text('Shop ${assign.id} not found'),
                      );
                    }
                    final data = shopSnap.data!.data()!;
                    final code = (data['code'] as String?) ?? assign.id;
                    final name = (data['name'] as String?) ?? '';
                    final area = (data['area'] as String?) ?? '';
                    final title = name.isEmpty ? code : '$name ($code)';
                    return GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
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
                            'tsaId': profile.uid,
                            'shopId': assign.id,
                            'shopTitle': name.isEmpty ? code : name,
                          },
                        ),
                      ),
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

  Widget _buildShopList(
    BuildContext context,
    String tsaId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    bool useGlobal = false,
  }) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final code = (data['code'] as String?) ?? doc.id;
        final name = (data['name'] as String?) ?? '';
        final area = (data['area'] as String?) ?? '';
        final title = name.isEmpty ? code : '$name ($code)';
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            subtitle: area.isEmpty
                ? null
                : Text(area, style: const TextStyle(color: AppTheme.mutedInk)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.toNamed(
              AppRoutes.dsfShopVisit,
              arguments: {
                'tsaId': useGlobal ? (data['tsaId'] ?? '') : tsaId,
                'shopId': doc.id,
                'shopTitle': name.isEmpty ? code : name,
              },
            ),
          ),
        );
      },
    );
  }

  Future<List<String>> _resolveDsfIds() async {
    final ids = <String>{};
    final session = Get.find<SessionService>();
    final profile = session.profile;
    if (profile != null && profile.uid.isNotEmpty) {
      ids.add(profile.uid);
    }
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email;
      if (email != null && email.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('dsfAccounts')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          ids.add(doc.id);
          final tsaId = doc.data()['tsaId'];
          if (tsaId is String && tsaId.isNotEmpty) {
            ids.add(tsaId);
          }
        }
      }
    } catch (_) {}
    return ids.toList();
  }
}
