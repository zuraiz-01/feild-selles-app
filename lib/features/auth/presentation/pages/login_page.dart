import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../../../../app/routes/app_routes.dart';

class LoginPage extends GetView<AuthController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    const String bootstrapSecret = String.fromEnvironment(
      'BOOTSTRAP_SECRET',
      defaultValue: '',
    );
    final bool showBootstrap = kDebugMode || bootstrapSecret.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.error.value != null) ...[
                Text(
                  controller.error.value!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                onChanged: (v) => controller.email.value = v,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => controller.password.value = v,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: controller.isLoading.value ? null : controller.login,
                child: controller.isLoading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
              if (showBootstrap) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.bootstrapAccounts),
                  child: const Text('Bootstrap accounts'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
