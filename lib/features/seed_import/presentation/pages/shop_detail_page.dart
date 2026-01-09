import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ShopDetailPage extends StatelessWidget {
  const ShopDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final tsaId = (args['tsaId'] as String?) ?? '';
    final shopId = (args['shopId'] as String?) ?? '';
    final shopTitle = (args['shopTitle'] as String?) ?? shopId;

    if (tsaId.isEmpty || shopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Missing tsaId/shopId')));
    }

    final salesCol = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops')
        .doc(shopId)
        .collection('sales');

    return Scaffold(
      appBar: AppBar(title: Text(shopTitle)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: salesCol.orderBy('sortKey').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No sales data found.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final label = (data['label'] as String?) ?? docs[index].id;
              final canola = (data['canola'] as num?)?.toDouble() ?? 0;
              final corn = (data['corn'] as num?)?.toDouble() ?? 0;
              final total = (data['total'] as num?)?.toDouble() ?? 0;

              return ListTile(
                title: Text(label),
                subtitle: Text('Canola: $canola • Corn: $corn • Total: $total'),
              );
            },
          );
        },
      ),
    );
  }
}

