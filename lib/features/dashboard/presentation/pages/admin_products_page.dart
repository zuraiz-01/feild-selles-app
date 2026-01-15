import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final productsCol = FirebaseFirestore.instance.collection('products');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add Excel default products',
            icon: const Icon(Icons.playlist_add),
            onPressed: () =>
                _seedExcelDefaults(context, productsCol: productsCol),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, productsCol: productsCol),
        child: const Icon(Icons.add),
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: productsCol.orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No products yet.'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['name'] as String?) ?? doc.id;
                final price = (data['price'] as num?)?.toDouble();
                final tax = (data['taxPct'] as num?)?.toDouble();
                final active = (data['active'] as bool?) ?? true;
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(
                      [
                        if (price != null) 'Price ${price.toStringAsFixed(2)}',
                        if (tax != null) 'Tax ${tax.toStringAsFixed(1)}%',
                        active ? 'Active' : 'Inactive',
                      ].join(' • '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(
                        context,
                        productsCol: productsCol,
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

  Future<void> _seedExcelDefaults(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> productsCol,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add default products'),
        content: const Text(
          'This will create products from the Excel format (CANOLA, CORN) if missing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    final now = FieldValue.serverTimestamp();
    const defaults = [
      {'id': 'canola', 'name': 'CANOLA'},
      {'id': 'corn', 'name': 'CORN'},
    ];

    for (final p in defaults) {
      final ref = productsCol.doc(p['id']!);
      batch.set(ref, {
        'name': p['name'],
        'active': true,
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
    if (!context.mounted) return;
    Get.snackbar(
      'Done',
      'Default products added.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> productsCol,
    String? existingId,
    Map<String, dynamic>? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? existingId ?? '',
    );
    final priceController = TextEditingController(
      text: (existing?['price'] as num?)?.toString() ?? '',
    );
    final taxController = TextEditingController(
      text: (existing?['taxPct'] as num?)?.toString() ?? '',
    );
    bool active = existing?['active'] != false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingId == null ? 'Add product' : 'Edit product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      readOnly: existingId != null,
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: taxController,
                      decoration: const InputDecoration(labelText: 'Tax %'),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                      title: const Text('Active'),
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
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final price = double.tryParse(priceController.text.trim());
                    final tax = double.tryParse(taxController.text.trim());
                    final payload = <String, dynamic>{
                      'name': name,
                      'active': active,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    if (price != null) payload['price'] = price;
                    if (tax != null) payload['taxPct'] = tax;
                    if (existingId == null) {
                      payload['createdAt'] = FieldValue.serverTimestamp();
                    }
                    await productsCol
                        .doc(existingId ?? name.toLowerCase())
                        .set(payload, SetOptions(merge: true));
                    if (context.mounted) Navigator.of(context).pop();
                    Get.snackbar(
                      'Saved',
                      'Product $name saved',
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
}
