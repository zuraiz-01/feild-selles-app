import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../products/data/models/product_model.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final productsCol = FirebaseFirestore.instance.collection('products');
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
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 2),
                Text(
                  'SKUs, rates, inventory',
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add Excel default products',
            icon: const Icon(Icons.playlist_add),
            onPressed: () =>
                _seedExcelDefaults(context, productsCol: productsCol),
          ),
          const SizedBox(width: 8),
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
              return const Center(
                child: Text('No products yet. Add your first.'),
              );
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final product = ProductModel.fromMap(
                  doc.data(),
                  fallbackId: doc.id,
                );
                final details = <String>[
                  'SKU ${product.sku}',
                  if (product.category != null) 'Category ${product.category}',
                  if (product.brand != null) 'Brand ${product.brand}',
                  if (product.unit != null) 'Unit ${product.unit}',
                  if (product.price != null)
                    'Rate Rs ${product.price!.toStringAsFixed(2)}/L',
                  if (product.stock != null)
                    'Stock ${product.stock!.toStringAsFixed(2)} L',
                ];
                return GlassCard(
                  onTap: () => _openForm(
                    context,
                    productsCol: productsCol,
                    existingId: doc.id,
                    existing: doc.data(),
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
                        child: const Icon(
                          Icons.inventory_2,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              details.join(' · '),
                              style: const TextStyle(color: AppTheme.mutedInk),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Delete product',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete product'),
                                  content: Text(
                                    'Delete "${product.name}"? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              await productsCol.doc(doc.id).delete();
                              if (!context.mounted) return;
                              Get.snackbar(
                                'Deleted',
                                'Product ${product.name} deleted',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openForm(
                              context,
                              productsCol: productsCol,
                              existingId: doc.id,
                              existing: doc.data(),
                            ),
                          ),
                        ],
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
    const defaults = [
      {'id': 'canola', 'sku': 'CANOLA', 'name': 'CANOLA'},
      {'id': 'corn', 'sku': 'CORN', 'name': 'CORN'},
    ];

    for (final p in defaults) {
      final ref = productsCol.doc(p['id']!);
      final product = ProductModel(sku: p['sku']!, name: p['name']!, unit: 'L');
      batch.set(ref, product.toMap(), SetOptions(merge: true));
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
    final existingProduct = existing == null
        ? null
        : ProductModel.fromMap(existing, fallbackId: existingId ?? '');
    final nameController = TextEditingController(
      text: existingProduct?.name ?? '',
    );
    final skuController = TextEditingController(
      text: existingProduct?.sku ?? existingId ?? '',
    );
    final rateController = TextEditingController(
      text: existingProduct?.price?.toStringAsFixed(2) ?? '',
    );
    final isEditing = existingId != null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
          title: Text(existingId == null ? 'Add product' : 'Edit product'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: skuController,
                    decoration: InputDecoration(
                      labelText: 'Product Code / SKU',
                      helperText: isEditing
                          ? 'SKU cannot be changed after create.'
                          : null,
                    ),
                    readOnly: isEditing,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate (per liter)',
                      prefixText: 'Rs ',
                      suffixText: '/L',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
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
                final sku = skuController.text.trim();
                final rate = double.tryParse(rateController.text.trim());
                if (name.isEmpty || sku.isEmpty) return;
                final product = ProductModel(
                  sku: sku,
                  name: name,
                  price: rate,
                  unit: 'L',
                );
                await productsCol
                    .doc(existingId ?? sku)
                    .set(product.toMap(), SetOptions(merge: true));
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
  }
}
