import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_toast.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';

class AdminDsfsPage extends StatelessWidget {
  const AdminDsfsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dsfCol = FirebaseFirestore.instance.collection('dsfAccounts');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(AppRoutes.adminDashboard),
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
              child: const Icon(Icons.manage_accounts, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage DSFs',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 2),
                Text(
                  'Accounts, geofence & access',
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: const [ThemeModeToggleButton(), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, dsfCol: dsfCol),
        child: const Icon(Icons.add),
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: dsfCol.orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No DSFs yet. Add your first.'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['name'] as String?) ?? doc.id;
                final email = (data['email'] as String?) ?? '';
                final geofence = data['geofence'];
                final radius =
                    (geofence is Map && geofence['radiusMeters'] is num)
                    ? (geofence['radiusMeters'] as num).toDouble()
                    : null;
                final waitSeconds = _readInt(data, 'shopVisitWaitSeconds');
                final waitLabel = waitSeconds == null
                    ? null
                    : '${(waitSeconds ~/ 60).toString().padLeft(2, '0')}:${(waitSeconds % 60).toString().padLeft(2, '0')}';
                final photoUrl = (data['photoUrl'] as String?)?.trim();
                return GlassCard(
                  onTap: () => _openForm(
                    context,
                    dsfCol: dsfCol,
                    existingId: doc.id,
                    existing: data,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? const Icon(Icons.badge, color: AppTheme.accent)
                            : Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.badge,
                                  color: AppTheme.accent,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (email.isNotEmpty) email,
                                if (radius != null)
                                  'Geofence ${radius.toStringAsFixed(0)} m',
                                if (waitLabel != null) 'Wait $waitLabel',
                              ].join(' · '),
                              style: const TextStyle(color: AppTheme.mutedInk),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(
                          context,
                          dsfCol: dsfCol,
                          existingId: doc.id,
                          existing: data,
                        ),
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

  Future<void> _openForm(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> dsfCol,
    String? existingId,
    Map<String, dynamic>? existing,
  }) async {
    final idController = TextEditingController(
      text: existingId ?? (existing?['tsaId'] as String?) ?? '',
    );
    final nameController = TextEditingController(
      text: (existing?['name'] as String?) ?? '',
    );
    final emailController = TextEditingController(
      text: (existing?['email'] as String?) ?? '',
    );
    final distributorController = TextEditingController(
      text: (existing?['distributorId'] as String?) ?? '',
    );
    final centerLatController = TextEditingController(
      text: _readNum(existing, 'geofence.center.lat'),
    );
    final centerLngController = TextEditingController(
      text: _readNum(existing, 'geofence.center.lng'),
    );
    final radiusController = TextEditingController(
      text: _readNum(existing, 'geofence.radiusMeters'),
    );
    final existingWaitSeconds =
        _readInt(existing, 'shopVisitWaitSeconds') ?? 300;
    final waitMinutesController = TextEditingController(
      text: (existingWaitSeconds ~/ 60).toString(),
    );
    final waitSecondsController = TextEditingController(
      text: (existingWaitSeconds % 60).toString().padLeft(2, '0'),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingId == null ? 'Add DSF' : 'Edit DSF'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'DSF ID / TSA ID',
                  ),
                  readOnly: existingId != null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: distributorController,
                  decoration: const InputDecoration(
                    labelText: 'Distributor ID',
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Geofence (lat/lng/radius m)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    if (compact) {
                      return Column(
                        children: [
                          TextField(
                            controller: centerLatController,
                            decoration: const InputDecoration(labelText: 'Lat'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: centerLngController,
                            decoration: const InputDecoration(labelText: 'Lng'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: radiusController,
                            decoration: const InputDecoration(
                              labelText: 'Radius (m)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: centerLatController,
                            decoration: const InputDecoration(labelText: 'Lat'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: centerLngController,
                            decoration: const InputDecoration(labelText: 'Lng'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: radiusController,
                            decoration: const InputDecoration(
                              labelText: 'Radius (m)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Shop arrival wait time',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: waitMinutesController,
                        decoration: const InputDecoration(labelText: 'Minutes'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: waitSecondsController,
                        decoration: const InputDecoration(
                          labelText: 'Seconds (0-59)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = idController.text.trim();
                final name = nameController.text.trim();
                if (id.isEmpty || name.isEmpty) return;
                final shopVisitWaitSeconds = _parseWaitSeconds(
                  minutes: waitMinutesController.text.trim(),
                  seconds: waitSecondsController.text.trim(),
                );
                if (shopVisitWaitSeconds == null) {
                  AppToast.warning(
                    'Invalid wait time',
                    message: 'Use minutes >= 0 and seconds 0..59.',
                  );
                  return;
                }
                final geo = _parseGeofence(
                  lat: centerLatController.text.trim(),
                  lng: centerLngController.text.trim(),
                  radius: radiusController.text.trim(),
                );
                final payload = <String, dynamic>{
                  'tsaId': id,
                  'name': name,
                  if (emailController.text.trim().isNotEmpty)
                    'email': emailController.text.trim(),
                  if (distributorController.text.trim().isNotEmpty)
                    'distributorId': distributorController.text.trim(),
                  'shopVisitWaitSeconds': shopVisitWaitSeconds,
                  if (geo != null) 'geofence': geo,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (existingId == null) {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                }
                await dsfCol.doc(id).set(payload, SetOptions(merge: true));
                if (context.mounted) Navigator.of(context).pop();
                AppToast.success('Saved', message: 'DSF $id saved');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic>? _parseGeofence({
    required String lat,
    required String lng,
    required String radius,
  }) {
    final latVal = double.tryParse(lat);
    final lngVal = double.tryParse(lng);
    final radVal = double.tryParse(radius);
    if (latVal == null || lngVal == null || radVal == null) return null;
    return {
      'center': {'lat': latVal, 'lng': lngVal},
      'radiusMeters': radVal,
    };
  }

  String _readNum(Map<String, dynamic>? data, String path) {
    if (data == null) return '';
    dynamic cur = data;
    for (final part in path.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return '';
      }
    }
    if (cur is num) return cur.toString();
    return '';
  }

  int? _readInt(Map<String, dynamic>? data, String path) {
    if (data == null) return null;
    dynamic cur = data;
    for (final part in path.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    if (cur is int) return cur;
    if (cur is num) return cur.toInt();
    if (cur is String) return int.tryParse(cur.trim());
    return null;
  }

  int? _parseWaitSeconds({required String minutes, required String seconds}) {
    final minVal = int.tryParse(minutes);
    final secVal = int.tryParse(seconds);
    if (minVal == null || secVal == null) return null;
    if (minVal < 0 || secVal < 0 || secVal > 59) return null;
    return (minVal * 60) + secVal;
  }
}
