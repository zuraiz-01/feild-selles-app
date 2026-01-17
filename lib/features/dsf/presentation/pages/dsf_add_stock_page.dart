import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';

class DsfAddStockPage extends StatefulWidget {
  const DsfAddStockPage({super.key});

  @override
  State<DsfAddStockPage> createState() => _DsfAddStockPageState();
}

class _DsfAddStockPageState extends State<DsfAddStockPage> {
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();
  String _selectedProductName = '';

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final existingRaw = args['existing'];
    final existing = <Map<String, dynamic>>[];
    if (existingRaw is List) {
      for (final item in existingRaw) {
        if (item is Map) {
          existing.add(item.cast<String, dynamic>());
        }
      }
    }

    final products = FirebaseFirestore.instance
        .collection('products')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Current Stock'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: existing),
            child: const Text('Done'),
          ),
        ],
      ),
      body: AppShell(
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search product',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: products,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final query = _searchController.text.trim().toLowerCase();
                  final docs = snapshot.data!.docs.where((d) {
                    final data = d.data();
                    final name = (data['name'] as String?) ?? d.id;
                    final sku = (data['sku'] as String?) ?? d.id;
                    if (query.isEmpty) return true;
                    return name.toLowerCase().contains(query) ||
                        sku.toLowerCase().contains(query);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('No products found.'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final name = (data['name'] as String?) ?? doc.id;
                      final sku = (data['sku'] as String?) ?? doc.id;
                      final price = (data['price'] as num?)?.toDouble();
                      final details = <String>[
                        if (sku.isNotEmpty) 'SKU: $sku',
                        if (price != null)
                          'Rate: ${price.toStringAsFixed(0)}',
                      ];
                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name),
                          subtitle: details.isEmpty
                              ? null
                              : Text(
                                  details.join(' • '),
                                  style: const TextStyle(
                                    color: AppTheme.mutedInk,
                                  ),
                                ),
                          trailing: const Icon(Icons.add),
                          onTap: () async {
                            setState(() {
                              _selectedProductName = name;
                              _qtyController.clear();
                            });
                            final ok = await _openQtyDialog(context);
                            if (ok != true) return;
                            final qtyRaw = _qtyController.text.trim();
                            if (qtyRaw.isEmpty) return;
                            final next = [
                              ...existing.where(
                                (e) => e['productId']?.toString() != doc.id,
                              ),
                              {
                                'productId': doc.id,
                                'productName': name,
                                'quantity': double.tryParse(qtyRaw) ?? qtyRaw,
                              },
                            ];
                            if (!mounted) return;
                            Get.back(result: next);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _openQtyDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _selectedProductName.isEmpty
                ? 'Add quantity'
                : 'Add quantity • $_selectedProductName',
          ),
          content: TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
