import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: AppShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              title: 'Control Center',
              subtitle: 'Seed data, manage accounts, monitor reports.',
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.seedImport),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Import Excel (Seed Data)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.seedTsaList),
                    icon: const Icon(Icons.people_alt_outlined),
                    label: const Text('View TSAs'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.adminDsfs),
                    icon: const Icon(Icons.manage_accounts),
                    label: const Text('Manage DSFs'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.adminShops),
                    icon: const Icon(Icons.store_mall_directory_outlined),
                    label: const Text('Manage Shops'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.adminProducts),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Manage Products'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.adminMap),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Live Map & Alerts'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.adminSeedSample),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Seed Sample Data'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.skySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.insights, color: AppTheme.sky),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Keep the data fresh by re-importing only when sheets change.',
                      style: TextStyle(color: AppTheme.mutedInk),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
