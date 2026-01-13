import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';

class AdminShopsPage extends StatelessWidget {
  const AdminShopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shopsCol = FirebaseFirestore.instance.collection('shops');
    return Scaffold(
      appBar: AppBar(title: const Text('Shops')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, shopsCol: shopsCol),
        child: const Icon(Icons.add),
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: shopsCol.orderBy('code').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No shops yet.'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final code = (data['code'] as String?) ?? doc.id;
                final name = (data['name'] as String?) ?? '';
                final filer = (data['filer'] as bool?) ?? false;
                final discount = (data['discountPct'] as num?)?.toDouble();
                final assigned = (data['assignedDsfId'] as String?) ?? '';
                return GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$code ${name.isEmpty ? '' : '- $name'}'),
                    subtitle: Text(
                      [
                        filer ? 'Filer' : 'Non-filer',
                        if (discount != null) 'Discount ${(discount * 100).toStringAsFixed(1)}%',
                        if (assigned.isNotEmpty) 'DSF $assigned',
                      ].join(' • '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(
                        context,
                        shopsCol: shopsCol,
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
    required CollectionReference<Map<String, dynamic>> shopsCol,
    String? existingId,
    Map<String, dynamic>? existing,
  }) async {
    final codeController =
        TextEditingController(text: existing?['code'] as String? ?? existingId ?? '');
    final nameController =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final areaController =
        TextEditingController(text: existing?['area'] as String? ?? '');
    final latController = TextEditingController(
      text: _readNum(existing, 'location.lat'),
    );
    final lngController = TextEditingController(
      text: _readNum(existing, 'location.lng'),
    );
    final dsfController =
        TextEditingController(text: existing?['assignedDsfId'] as String? ?? '');
    final schedule = Map<String, bool>.fromEntries(
      const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
          .map((d) => MapEntry(d, (existing?['schedule'] as Map?)?[d] == true)),
    );
    bool filer = existing?['filer'] == true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingId == null ? 'Add shop' : 'Edit shop'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: 'Code'),
                      readOnly: existingId != null,
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: areaController,
                      decoration: const InputDecoration(labelText: 'Area'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: filer,
                      onChanged: (v) => setState(() => filer = v),
                      title: const Text('Filer (5% discount)'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration: const InputDecoration(labelText: 'Lat'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lngController,
                            decoration: const InputDecoration(labelText: 'Lng'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dsfController,
                      decoration:
                          const InputDecoration(labelText: 'Assigned DSF ID'),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Schedule',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: schedule.keys
                          .map(
                            (d) => FilterChip(
                              label: Text(d.toUpperCase()),
                              selected: schedule[d] == true,
                              onSelected: (v) {
                                setState(() {
                                  schedule[d] = v;
                                });
                              },
                            ),
                          )
                          .toList(),
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
                    final code = codeController.text.trim();
                    if (code.isEmpty) return;
                    final payload = <String, dynamic>{
                      'code': code,
                      'name': nameController.text.trim(),
                      'area': areaController.text.trim(),
                      'filer': filer,
                      'discountPct': filer ? 0.05 : 0.025,
                      'assignedDsfId': dsfController.text.trim(),
                      'schedule': schedule,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());
                    if (lat != null && lng != null) {
                      payload['location'] = {'lat': lat, 'lng': lng};
                    }
                    if (existingId == null) {
                      payload['createdAt'] = FieldValue.serverTimestamp();
                    }
                    await shopsCol
                        .doc(existingId ?? code.toLowerCase())
                        .set(payload, SetOptions(merge: true));
                    if (context.mounted) Navigator.of(context).pop();
                    Get.snackbar(
                      'Saved',
                      'Shop $code saved',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
