import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../products/data/models/product_model.dart';

class DsfProductsPage extends StatelessWidget {
  const DsfProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final productsCol = FirebaseFirestore.instance.collection('products');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
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
                final product =
                    ProductModel.fromMap(doc.data(), fallbackId: doc.id);
                final details = <String>[
                  'SKU ${product.sku}',
                  if (product.category != null)
                    'Category ${product.category}',
                  if (product.brand != null) 'Brand ${product.brand}',
                  if (product.unit != null) 'Unit ${product.unit}',
                  if (product.price != null)
                    'Rate ${product.price!.toStringAsFixed(2)}',
                  if (product.stock != null)
                    'Stock ${product.stock!.toStringAsFixed(2)}',
                ];
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text(
                      details.join(' • '),
                      style: const TextStyle(color: AppTheme.mutedInk),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(
                        context,
                        productsCol: productsCol,
                        existingId: doc.id,
                        existing: doc.data(),
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
    required CollectionReference<Map<String, dynamic>> productsCol,
    required String existingId,
    required Map<String, dynamic> existing,
  }) async {
    final existingProduct =
        ProductModel.fromMap(existing, fallbackId: existingId);
    final nameController = TextEditingController(text: existingProduct.name);
    final skuController = TextEditingController(text: existingProduct.sku);
    final categoryController =
        TextEditingController(text: existingProduct.category ?? '');
    final brandController =
        TextEditingController(text: existingProduct.brand ?? '');
    final unitController =
        TextEditingController(text: existingProduct.unit ?? '');
    final priceController =
        TextEditingController(text: existingProduct.price?.toString() ?? '');
    final stockController =
        TextEditingController(text: existingProduct.stock?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update product details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(
                    labelText: 'Product Code / SKU',
                  ),
                  readOnly: true,
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(labelText: 'Brand'),
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price / Rate'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock / Quantity',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                String? cleanText(String raw) {
                  final trimmed = raw.trim();
                  return trimmed.isEmpty ? null : trimmed;
                }

                double? parseNumber(String raw) {
                  final trimmed = raw.trim();
                  if (trimmed.isEmpty) return null;
                  return double.tryParse(trimmed);
                }

                final name = nameController.text.trim();
                final sku = skuController.text.trim();
                if (name.isEmpty || sku.isEmpty) return;
                final product = ProductModel(
                  sku: sku,
                  name: name,
                  category: cleanText(categoryController.text),
                  brand: cleanText(brandController.text),
                  unit: cleanText(unitController.text),
                  price: parseNumber(priceController.text),
                  stock: parseNumber(stockController.text),
                );
                await productsCol
                    .doc(existingId)
                    .set(product.toMap(), SetOptions(merge: true));
                if (context.mounted) Navigator.of(context).pop();
                Get.snackbar(
                  'Saved',
                  'Product $name updated',
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
