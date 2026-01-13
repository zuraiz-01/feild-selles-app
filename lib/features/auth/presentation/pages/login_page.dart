import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../../../../app/routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    const String bootstrapSecret = String.fromEnvironment(
      'BOOTSTRAP_SECRET',
      defaultValue: '',
    );
    final bool showBootstrap = kDebugMode || bootstrapSecret.isNotEmpty;

    return Scaffold(
      body: AppShell(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.visibility, color: AppTheme.accent),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sign in to continue your workflow',
                                  style: TextStyle(color: AppTheme.mutedInk),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        child: Obx(
                          () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (controller.error.value != null) ...[
                                Text(
                                  controller.error.value!,
                                  style: const TextStyle(color: Color(0xFFD05353)),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                onChanged: (v) => controller.email.value = v,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                onChanged: (v) => controller.password.value = v,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    tooltip: _showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed:
                                    controller.isLoading.value ? null : controller.login,
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
                                  onPressed: () =>
                                      Get.toNamed(AppRoutes.bootstrapAccounts),
                                  child: const Text('Bootstrap accounts'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
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
}
