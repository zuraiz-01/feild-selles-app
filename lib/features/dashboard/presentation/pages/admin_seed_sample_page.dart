import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../products/data/models/product_model.dart';

class AdminSeedSamplePage extends StatefulWidget {
  const AdminSeedSamplePage({super.key});

  @override
  State<AdminSeedSamplePage> createState() => _AdminSeedSamplePageState();
}

class _AdminSeedSamplePageState extends State<AdminSeedSamplePage> {
  bool _isSeeding = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Sample Data')),
      body: AppShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This will create sample DSF, shops, products, and a geofence for quick testing.',
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Text(
                _status!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSeeding ? null : _seed,
              icon: _isSeeding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isSeeding ? 'Seeding...' : 'Create Sample Data'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seed() async {
    setState(() {
      _isSeeding = true;
      _status = 'Running...';
    });
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Sample DSF
      const dsfId = 'dsf_demo';
      const dsfUid = 'dsf_demo_uid';
      final dsfRef =
          FirebaseFirestore.instance.collection('dsfAccounts').doc(dsfId);
      batch.set(dsfRef, {
        'tsaId': dsfId,
        'uid': dsfUid,
        'name': 'Demo DSF',
        'email': 'dsf_demo@field.local',
        'distributorId': 'dist_demo',
        'geofence': {
          'center': {'lat': 24.8607, 'lng': 67.0011},
          'radiusMeters': 800,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Sample shops
      final shopsCol = FirebaseFirestore.instance.collection('shops');
      final schedule = {
        'mon': true,
        'tue': true,
        'wed': true,
        'thu': true,
        'fri': true,
        'sat': false,
        'sun': false,
      };
      final shops = [
        {
          'id': 'shop_alpha',
          'code': 'ALPHA',
          'name': 'Alpha Store',
          'area': 'Downtown',
          'filer': true,
          'discountPct': 0.05,
          'location': {'lat': 24.8615, 'lng': 67.0099},
        },
        {
          'id': 'shop_beta',
          'code': 'BETA',
          'name': 'Beta Traders',
          'area': 'Market',
          'filer': false,
          'discountPct': 0.025,
          'location': {'lat': 24.8585, 'lng': 67.0005},
        },
      ];
      for (final shop in shops) {
        final ref = shopsCol.doc(shop['id'] as String);
        batch.set(ref, {
          ...shop,
          'assignedDsfId': dsfUid,
          'schedule': schedule,
          'tsaId': dsfId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Sample products
      final productsCol = FirebaseFirestore.instance.collection('products');
      final products = [
        ProductModel(
          sku: 'prod_oil',
          name: 'Cooking Oil 1L',
          category: 'Oil',
          unit: 'L',
          price: 1200.0,
          stock: 0.0,
        ),
        ProductModel(
          sku: 'prod_corn',
          name: 'Corn Oil 1L',
          category: 'Oil',
          unit: 'L',
          price: 1350.0,
          stock: 0.0,
        ),
      ];
      for (final p in products) {
        final ref = productsCol.doc(p.sku);
        batch.set(ref, p.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
      if (!mounted) return;
      setState(() {
        _status =
            'Done. DSF: dsf_demo (uid: dsf_demo_uid), Shops: ALPHA/BETA, Products created.';
      });
      Get.snackbar(
        'Seeded',
        'Sample data created.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Failed: $e';
      });
      Get.snackbar(
        'Seed failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }
}
