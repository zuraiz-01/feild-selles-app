import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

class DistributorDashboardPage extends StatelessWidget {
  const DistributorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distributor Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: () => Get.toNamed(AppRoutes.seedTsaList),
              child: const Text('View TSAs'),
            ),
          ],
        ),
      ),
    );
  }
}
