import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/logged_in_name_text.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = <_AdminActionItem>[
      _AdminActionItem(
        order: 0,
        icon: Icons.people_alt_outlined,
        title: 'View TSAs',
        subtitle: 'Review territory staff.',
        onTap: () => Get.toNamed(AppRoutes.seedTsaList),
      ),
      _AdminActionItem(
        order: 1,
        icon: Icons.store_mall_directory_outlined,
        title: 'Manage Shops',
        subtitle: 'Retail network upkeep.',
        onTap: () => Get.toNamed(AppRoutes.adminShops),
      ),
      _AdminActionItem(
        order: 2,
        icon: Icons.inventory_2_outlined,
        title: 'Manage Products',
        subtitle: 'Catalog and SKUs.',
        onTap: () => Get.toNamed(AppRoutes.adminProducts),
      ),
      _AdminActionItem(
        order: 3,
        icon: Icons.map_outlined,
        title: 'Live Map & Alerts',
        subtitle: 'See coverage heat.',
        onTap: () => Get.toNamed(AppRoutes.adminMap),
      ),
      _AdminActionItem(
        order: 4,
        icon: Icons.admin_panel_settings_outlined,
        title: 'Admin Accounts',
        subtitle: 'Create admin logins.',
        onTap: () => Get.toNamed(AppRoutes.bootstrapAccounts),
      ),
    ];

    if (kIsWeb) {
      return _WebAdminDashboard(
        actions: actions,
        isDark: isDark,
        onLogout: authController.logout,
      );
    }

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Admin HQ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 2),
                LoggedInNameText(
                  prefix: 'Hi, ',
                  fallback: 'Admin',
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const ThemeModeToggleButton(),
          TextButton.icon(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.ink,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(96, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: isDark
                  ? AppTheme.skySoft.withValues(alpha: 0.7)
                  : AppTheme.accentSoft,
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
                    children: actions
                        .map(
                          (item) => _AdminAction(
                            order: item.order,
                            icon: item.icon,
                            title: item.title,
                            subtitle: item.subtitle,
                            onTap: item.onTap,
                          ),
                        )
                        .toList(),
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

class _AdminActionItem {
  final int order;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionItem({
    required this.order,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _WebAdminDashboard extends StatelessWidget {
  final List<_AdminActionItem> actions;
  final bool isDark;
  final VoidCallback onLogout;

  const _WebAdminDashboard({
    required this.actions,
    required this.isDark,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 70,
        title: const Text('Admin Dashboard'),
        actions: [
          const ThemeModeToggleButton(),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.ink,
              backgroundColor: isDark
                  ? AppTheme.skySoft.withValues(alpha: 0.7)
                  : AppTheme.accentSoft,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AppShell(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactWeb = constraints.maxWidth < 980;
            final gridColumns = constraints.maxWidth >= 1200
                ? 2
                : constraints.maxWidth >= 700
                ? 2
                : 1;

            Widget primaryContent() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Control Center',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Manage TSAs, shops, products and live tracking from one place.',
                          style: TextStyle(color: AppTheme.mutedInk),
                        ),
                        SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Tag(label: 'Admin', icon: Icons.shield_moon),
                            _Tag(label: 'Web View', icon: Icons.web),
                            _Tag(label: 'Live', icon: Icons.cloud_done),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: gridColumns == 1 ? 2.8 : 2.3,
                    ),
                    itemCount: actions.length,
                    itemBuilder: (context, index) {
                      final item = actions[index];
                      return _WebAdminActionCard(item: item);
                    },
                  ),
                ],
              );
            }

            Widget sidePanel() {
              return Column(
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Overview',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 10),
                        _WebStatRow(label: 'Role', value: 'Admin'),
                        _WebStatRow(label: 'Mode', value: 'Web'),
                        _WebStatRow(label: 'Workspace', value: 'HQ'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Tip',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use Live Map & Alerts for real-time movement and pending actions.',
                          style: TextStyle(color: AppTheme.mutedInk),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: isCompactWeb
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            primaryContent(),
                            const SizedBox(height: 16),
                            sidePanel(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: primaryContent()),
                            const SizedBox(width: 16),
                            SizedBox(width: 320, child: sidePanel()),
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

class _WebAdminActionCard extends StatelessWidget {
  final _AdminActionItem item;

  const _WebAdminActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: item.onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: AppTheme.mutedInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.mutedInk,
          ),
        ],
      ),
    );
  }
}

class _WebStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _WebStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.mutedInk),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ],
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
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
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
                  mainAxisSize: MainAxisSize.max,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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
