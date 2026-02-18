import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';

class DsfAddOrderPage extends StatefulWidget {
  const DsfAddOrderPage({super.key});

  @override
  State<DsfAddOrderPage> createState() => _DsfAddOrderPageState();
}

class _DsfAddOrderPageState extends State<DsfAddOrderPage> {
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();

  String _selectedProductName = '';
  String _selectedProductUnit = '';
  final List<Map<String, dynamic>> _orders = [];
  bool _loadedExisting = false;

  String _normalizeUnit(dynamic raw) {
    final unit = raw?.toString().trim() ?? '';
    if (unit.isEmpty) return 'L';
    final lower = unit.toLowerCase();
    if (lower == 'l' ||
        lower == 'ltr' ||
        lower == 'liter' ||
        lower == 'litre') {
      return 'L';
    }
    return unit;
  }

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
    if (!_loadedExisting && existingRaw is List) {
      for (final item in existingRaw) {
        if (item is Map) {
          _orders.add(item.cast<String, dynamic>());
        }
      }
      _loadedExisting = true;
    }
    final products = FirebaseFirestore.instance
        .collection('products')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Order'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: _orders),
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
                      final unit = _normalizeUnit(data['unit']);
                      final price = (data['price'] as num?)?.toDouble();
                      final details = <String>[
                        if (sku.isNotEmpty) 'SKU: $sku',
                        if (unit.isNotEmpty) 'Unit: $unit',
                        if (price != null)
                          'Rate: Rs ${price.toStringAsFixed(2)}/L',
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
                              _selectedProductUnit = unit;
                              _qtyController.clear();
                            });
                            final ok = await _openQtyDialog(context);
                            if (ok != true) return;
                            final qtyRaw = _qtyController.text.trim();
                            if (qtyRaw.isEmpty) return;
                            final parsed = double.tryParse(qtyRaw);
                            if (parsed == null) {
                              Get.snackbar(
                                'Error adding product',
                                'Please enter a valid quantity.',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }
                            setState(() {
                              _orders.add({
                                'productId': doc.id,
                                'productName': name,
                                'quantity': parsed,
                                'unit': _selectedProductUnit.isNotEmpty
                                    ? _selectedProductUnit
                                    : 'L',
                                if (price != null) 'pricePerLiter': price,
                                if (price != null) 'lineAmount': parsed * price,
                              });
                            });
                            Get.snackbar(
                              'Added',
                              '$name ${parsed.toStringAsFixed(2)} ${_selectedProductUnit.isNotEmpty ? _selectedProductUnit : 'L'}',
                              snackPosition: SnackPosition.BOTTOM,
                            );
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
                : _selectedProductUnit.isEmpty
                ? 'Add quantity • $_selectedProductName'
                : 'Add quantity • $_selectedProductName ($_selectedProductUnit)',
          ),
          content: TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity (liters)',
              suffixText: _selectedProductUnit.isNotEmpty
                  ? _selectedProductUnit
                  : 'L',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = _qtyController.text.trim();
                if (qty.isEmpty) {
                  Get.snackbar(
                    'Error adding product',
                    'Please enter quantity.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
                final parsed = double.tryParse(qty);
                if (parsed == null) {
                  Get.snackbar(
                    'Error adding product',
                    'Please enter a valid quantity.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
