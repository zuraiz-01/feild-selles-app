import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool constrainOnWeb;
  final double webMaxWidth;

  const AppShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.constrainOnWeb = true,
    this.webMaxWidth = 1360,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (kIsWeb && constrainOnWeb) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: webMaxWidth),
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundFor(Theme.of(context).brightness),
      ),
      child: SafeArea(
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(28);
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x26000000) : const Color(0x1A1E4A3E),
            blurRadius: isDark ? 22 : 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
