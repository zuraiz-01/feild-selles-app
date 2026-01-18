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
        titleSpacing: 20,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppTheme.warmSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.local_cafe, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin HQ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 2),
                Text(
                  'Brewing controls & data',
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.ink,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: AppTheme.accentSoft,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AppShell(
        child: ListView(
          children: [
            Row(
              children: [
                _Tag(label: 'Admin', icon: Icons.shield_moon),
                const SizedBox(width: 8),
                _Tag(label: 'Live', icon: Icons.cloud_done),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Control Center',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Seed data, manage accounts, monitor reports.',
                    style: TextStyle(color: AppTheme.mutedInk),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    runSpacing: 12,
                    spacing: 12,
                    children: [
                      _AdminAction(
                        order: 0,
                        icon: Icons.people_alt_outlined,
                        title: 'View TSAs',
                        subtitle: 'Review territory staff.',
                        onTap: () => Get.toNamed(AppRoutes.seedTsaList),
                      ),
                      _AdminAction(
                        order: 1,
                        icon: Icons.manage_accounts,
                        title: 'Manage DSFs',
                        subtitle: 'Accounts, permissions, resets.',
                        onTap: () => Get.toNamed(AppRoutes.adminDsfs),
                      ),
                      _AdminAction(
                        order: 2,
                        icon: Icons.store_mall_directory_outlined,
                        title: 'Manage Shops',
                        subtitle: 'Retail network upkeep.',
                        onTap: () => Get.toNamed(AppRoutes.adminShops),
                      ),
                      _AdminAction(
                        order: 3,
                        icon: Icons.inventory_2_outlined,
                        title: 'Manage Products',
                        subtitle: 'Catalog and SKUs.',
                        onTap: () => Get.toNamed(AppRoutes.adminProducts),
                      ),
                      _AdminAction(
                        order: 4,
                        icon: Icons.map_outlined,
                        title: 'Live Map & Alerts',
                        subtitle: 'See coverage heat.',
                        onTap: () => Get.toNamed(AppRoutes.adminMap),
                      ),
                      _AdminAction(
                        order: 5,
                        icon: Icons.auto_awesome,
                        title: 'Experiments',
                        subtitle: 'Coming soon.',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AdminAction extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int order;

  const _AdminAction({
    required this.order,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_AdminAction> createState() => _AdminActionState();
}

class _AdminActionState extends State<_AdminAction> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 260 + (widget.order * 80)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.warmSoft, AppTheme.accentSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _pressed
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: AppTheme.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Tag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.skySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
