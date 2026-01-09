import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TsaListPage extends StatelessWidget {
  const TsaListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('seedTsas');

    return Scaffold(
      appBar: AppBar(title: const Text('TSAs')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No TSA data. Import Excel first.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] as String?) ?? doc.id;
              final sheetName = (data['sheetName'] as String?) ?? '';

              return ListTile(
                title: Text(name),
                subtitle: sheetName.isEmpty ? null : Text(sheetName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(
                  '/seed/tsa',
                  arguments: {'tsaId': doc.id, 'tsaName': name},
                ),
              );
            },
          );
        },
      ),
    );
  }
}

