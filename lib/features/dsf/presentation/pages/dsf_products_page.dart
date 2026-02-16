import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../products/data/models/product_model.dart';

class DsfProductsPage extends StatelessWidget {
  const DsfProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final productsCol = FirebaseFirestore.instance.collection('products');
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
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
            return ListView(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warmSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Product updates are admin-only. DSF can view products only.',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...List.generate(docs.length, (index) {
                  final doc = docs[index];
                  final product = ProductModel.fromMap(
                    doc.data(),
                    fallbackId: doc.id,
                  );
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

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == docs.length - 1 ? 0 : 12,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name),
                        subtitle: Text(
                          details.join(' | '),
                          style: const TextStyle(color: AppTheme.mutedInk),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
