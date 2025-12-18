import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../duty/presentation/controllers/duty_controller.dart';

class DsfHomePage extends StatelessWidget {
  const DsfHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dutyController = Get.find<DutyController>();
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSF'),
        actions: [
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GetBuilder<DutyController>(
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dutyController.error.value != null) ...[
                Text(
                  dutyController.error.value!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              Text('Active Duty: ${dutyController.activeDutyId ?? '-'}'),
              const SizedBox(height: 16),
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
                child: const Text('End Duty (Upload Report)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    dutyController.isLoading.value ||
                        dutyController.activeDutyId == null
                    ? null
                    : () => dutyController.endDuty(uploadReport: false),
                child: const Text('End Duty (Local Only)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
