import 'package:cloud_firestore/cloud_firestore.dart';
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

    final weekday = _weekdayKey(DateTime.tryParse('$dateKey 00:00:00') ??
        DateTime.now());

    final shopsQuery = FirebaseFirestore.instance
        .collection('shops')
        .where('assignedDsfId', isEqualTo: profile.uid)
        .where('schedule.$weekday', isEqualTo: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Shops to Visit')),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: shopsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'No shops assigned for today ($weekday).',
                  textAlign: TextAlign.center,
                ),
              );
            }
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
                    title: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: area.isEmpty
                        ? null
                        : Text(
                            area,
                            style: const TextStyle(color: AppTheme.mutedInk),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Get.toNamed(
                      AppRoutes.dsfShopVisit,
                      arguments: {
                        'tsaId': data['tsaId'] ?? '',
                        'shopId': doc.id,
                        'shopTitle': name.isEmpty ? doc.id : name,
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _weekdayKey(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
      default:
        return 'sun';
    }
  }
}
