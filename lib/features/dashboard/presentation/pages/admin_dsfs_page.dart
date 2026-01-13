import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';

class AdminDsfsPage extends StatelessWidget {
  const AdminDsfsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dsfCol = FirebaseFirestore.instance.collection('dsfAccounts');
    return Scaffold(
      appBar: AppBar(title: const Text('DSFs')),
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
              return const Center(child: Text('No DSFs yet.'));
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
                return GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(
                      [
                        if (email.isNotEmpty) email,
                        if (radius != null) 'Geofence: ${radius.toStringAsFixed(0)} m',
                      ].join(' • '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(
                        context,
                        dsfCol: dsfCol,
                        existingId: doc.id,
                        existing: data,
                      ),
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

  Future<void> _openForm(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> dsfCol,
    String? existingId,
    Map<String, dynamic>? existing,
  }) async {
    final idController =
        TextEditingController(text: existingId ?? (existing?['tsaId'] as String?) ?? '');
    final nameController =
        TextEditingController(text: (existing?['name'] as String?) ?? '');
    final emailController =
        TextEditingController(text: (existing?['email'] as String?) ?? '');
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
                  decoration: const InputDecoration(labelText: 'DSF ID / TSA ID'),
                  readOnly: existingId != null,
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
                TextField(
                  controller: distributorController,
                  decoration: const InputDecoration(labelText: 'Distributor ID'),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Geofence (lat/lng/radius m)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
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
                        decoration: const InputDecoration(labelText: 'Radius m'),
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
                  if (geo != null) 'geofence': geo,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (existingId == null) {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                }
                await dsfCol.doc(id).set(payload, SetOptions(merge: true));
                if (context.mounted) Navigator.of(context).pop();
                Get.snackbar(
                  'Saved',
                  'DSF $id saved',
                  snackPosition: SnackPosition.BOTTOM,
                );
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
}
