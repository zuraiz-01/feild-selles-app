import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TsaDetailPage extends StatelessWidget {
  const TsaDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final tsaId = (args['tsaId'] as String?) ?? '';
    final tsaName = (args['tsaName'] as String?) ?? tsaId;

    if (tsaId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Missing tsaId')));
    }

    final shopsCol = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops');

    return Scaffold(
      appBar: AppBar(title: Text(tsaName)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            return const Center(child: Text('No shops found.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final code = (data['code'] as String?) ?? doc.id;
              final name = (data['name'] as String?) ?? '';
              final area = (data['area'] as String?) ?? '';

              return ListTile(
                title: Text('$code ${name.isEmpty ? '' : '• $name'}'),
                subtitle: area.isEmpty ? null : Text(area),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(
                  '/seed/shop',
                  arguments: {
                    'tsaId': tsaId,
                    'shopId': doc.id,
                    'shopTitle': '$code ${name.isEmpty ? '' : '• $name'}',
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

