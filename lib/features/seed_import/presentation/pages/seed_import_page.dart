import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../controllers/seed_import_controller.dart';

class SeedImportPage extends GetView<SeedImportController> {
  const SeedImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Import (Excel → Firestore)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final running = controller.isRunning.value;
          final err = controller.error.value;
          final result = controller.lastResult.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(controller.status.value),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: running ? controller.progress.value : null),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: running ? null : controller.importFromBundledExcelAsset,
                child: Text(running ? 'Importing...' : 'Import bundled Excel'),
              ),
              const SizedBox(height: 12),
              if (err != null) ...[
                Text(err, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              if (result != null) ...[
                Text('TSAs: ${result.tsaCount}'),
                Text('Shops: ${result.shopCount}'),
                Text('Shop sales docs: ${result.saleDocsCount}'),
                const SizedBox(height: 8),
                Text('Distributor sheets: ${result.distributorCount}'),
                Text('Parties: ${result.partyCount}'),
                Text('Distributor sales docs: ${result.distributorSaleDocsCount}'),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Get.toNamed(AppRoutes.seedTsaList),
                child: const Text('View TSAs'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
