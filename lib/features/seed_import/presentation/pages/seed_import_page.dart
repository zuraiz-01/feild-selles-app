import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/seed_import_controller.dart';

class SeedImportPage extends GetView<SeedImportController> {
  const SeedImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seed Import'),
        actions: [
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: AppShell(
        child: Obx(() {
          final running = controller.isRunning.value;
          final err = controller.error.value;
          final result = controller.lastResult.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                title: 'Excel to Firestore',
                subtitle: 'Upload your bundled sheet and prepare accounts.',
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      controller.status.value,
                      style: const TextStyle(color: AppTheme.mutedInk),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: running ? controller.progress.value : null,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE8EAF4),
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          running ? null : controller.importFromBundledExcelAsset,
                      child: Text(running ? 'Importing...' : 'Import bundled Excel'),
                    ),
                    const SizedBox(height: 12),
                    if (err != null) ...[
                      Text(err, style: const TextStyle(color: Color(0xFFD05353))),
                      const SizedBox(height: 12),
                    ],
                    if (result != null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatChip(label: 'TSAs', value: '${result.tsaCount}'),
                          _StatChip(label: 'Shops', value: '${result.shopCount}'),
                          _StatChip(
                            label: 'Shop sales',
                            value: '${result.saleDocsCount}',
                          ),
                          _StatChip(
                            label: 'Distributors',
                            value: '${result.distributorCount}',
                          ),
                          _StatChip(label: 'Parties', value: '${result.partyCount}'),
                          _StatChip(
                            label: 'Distributor sales',
                            value: '${result.distributorSaleDocsCount}',
                          ),
                          _StatChip(
                            label: 'DSF created',
                            value: '${controller.dsfCreated.value}',
                            tint: AppTheme.accentSoft,
                          ),
                          _StatChip(
                            label: 'DSF failed',
                            value: '${controller.dsfFailed.value}',
                            tint: AppTheme.warmSoft,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.seedTsaList),
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('View TSAs'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? tint;

  const _StatChip({
    required this.label,
    required this.value,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint ?? const Color(0xFFF1F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
