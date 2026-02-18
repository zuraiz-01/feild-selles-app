import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/logged_in_name_text.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../duty/presentation/controllers/duty_controller.dart';

class DsfHomePage extends StatelessWidget {
  const DsfHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dutyController = Get.find<DutyController>();
    final authController = Get.find<AuthController>();
    final todayLabel = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: const Text('DSF Dashboard'),
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
          child: GetBuilder<DutyController>(
            builder: (_) {
              final isDutyActive = dutyController.activeDutyId != null;
              final isLoading = dutyController.isLoading.value;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
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
                                  children: [
                                    const Text(
                                      'Field Operations',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        color: AppTheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Today: $todayLabel',
                                      style: const TextStyle(
                                        color: AppTheme.mutedInk,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isDutyActive
                                          ? 'Status: Active duty'
                                          : 'Status: Duty not started',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: GlassCard(
                                      onTap: () =>
                                          Get.toNamed(AppRoutes.dsfShops),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.storefront,
                                            color: AppTheme.accent,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Shops to Visit',
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
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GlassCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ElevatedButton(
                                            onPressed: isLoading || isDutyActive
                                                ? null
                                                : dutyController.startDuty,
                                            child: const Text('Start Duty'),
                                          ),
                                          const SizedBox(height: 10),
                                          ElevatedButton(
                                            onPressed:
                                                isLoading || !isDutyActive
                                                ? null
                                                : () => dutyController.endDuty(
                                                    uploadReport: true,
                                                  ),
                                            child: const Text('End Duty'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (dutyController.error.value != null) ...[
                                const SizedBox(height: 12),
                                GlassCard(
                                  child: Text(
                                    dutyController.error.value!,
                                    style: const TextStyle(
                                      color: Color(0xFFD05353),
                                    ),
                                  ),
                                ),
                              ],
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
                                  'Live Notes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Start duty before visit submission. End duty after completing shop activities.',
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
              );
            },
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
            Text('DSF Panel', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            LoggedInNameText(
              prefix: 'Hi, ',
              fallback: 'DSF',
              style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
            ),
          ],
        ),
        actions: [
          const ThemeModeToggleButton(),
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AppShell(
        child: GetBuilder<DutyController>(
          builder: (_) => ListView(
            children: [
              const SectionTitle(
                title: 'Today',
                subtitle: 'Track your duty status and reports.',
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dutyController.error.value != null) ...[
                      Text(
                        dutyController.error.value!,
                        style: const TextStyle(color: Color(0xFFD05353)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.skySoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: AppTheme.sky,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Today: $todayLabel',
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.dsfShops),
                      icon: const Icon(Icons.storefront),
                      label: const Text('Shops to Visit'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          dutyController.isLoading.value ||
                              dutyController.activeDutyId != null
                          ? null
                          : dutyController.startDuty,
                      child: dutyController.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Start Duty'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          dutyController.isLoading.value ||
                              dutyController.activeDutyId == null
                          ? null
                          : () => dutyController.endDuty(uploadReport: true),
                      child: const Text('End Duty'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
