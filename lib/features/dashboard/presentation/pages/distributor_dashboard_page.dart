import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/logged_in_name_text.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class DistributorDashboardPage extends StatelessWidget {
  const DistributorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: const Text('Distributor Dashboard'),
          actions: [
            const ThemeModeToggleButton(),
            TextButton.icon(
              onPressed: () => authController.logout(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: AppShell(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Distributor Workspace',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: AppTheme.ink,
                                ),
                              ),
                              SizedBox(height: 6),
                              LoggedInNameText(
                                prefix: 'Hi, ',
                                fallback: 'Distributor',
                                style: TextStyle(color: AppTheme.mutedInk),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          onTap: () => Get.toNamed(AppRoutes.seedTsaList),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.store_mall_directory_outlined,
                                color: AppTheme.accent,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'View TSAs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: AppTheme.mutedInk,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 320,
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Quick Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Review TSA progress and outlet coverage from the master list.',
                            style: TextStyle(color: AppTheme.mutedInk),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
          const ThemeModeToggleButton(),
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
