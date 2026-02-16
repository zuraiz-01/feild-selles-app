import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/logged_in_name_text.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../duty/presentation/controllers/duty_controller.dart';

class DsfHomePage extends StatelessWidget {
  const DsfHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dutyController = Get.find<DutyController>();
    final authController = Get.find<AuthController>();
    final todayLabel = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());

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
