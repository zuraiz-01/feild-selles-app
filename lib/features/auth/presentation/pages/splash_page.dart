import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../controllers/splash_controller.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      builder: (_) {
        return Scaffold(
          body: AppShell(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.warmSoft, AppTheme.accentSoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_cafe,
                      size: 44,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Field Sales App',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Brewing your workspace...',
                  style: TextStyle(color: AppTheme.mutedInk),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
