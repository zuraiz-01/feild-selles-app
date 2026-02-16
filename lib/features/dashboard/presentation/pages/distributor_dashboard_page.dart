import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/logged_in_name_text.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class DistributorDashboardPage extends StatelessWidget {
  const DistributorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Distributor', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            LoggedInNameText(
              prefix: 'Hi, ',
              fallback: 'Distributor',
              style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
            ),
          ],
        ),
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
              title: 'Distributor Workspace',
              subtitle: 'Track TSA data and review outlets.',
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.seedTsaList),
                    icon: const Icon(Icons.store_mall_directory_outlined),
                    label: const Text('View TSAs'),
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
                      color: AppTheme.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.track_changes,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Stay on top of TSA activity and shop performance insights.',
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
