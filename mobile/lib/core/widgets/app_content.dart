import 'package:flutter/material.dart';

class AppContent extends StatelessWidget {
  const AppContent({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.topPadding = 16,
    this.horizontalPadding,
  });

  final Widget child;
  final double maxWidth;
  final double topPadding;
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final horizontal =
        horizontalPadding ??
        (MediaQuery.sizeOf(context).width >= 720 ? 24.0 : 16.0);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, topPadding, horizontal, 32),
          child: child,
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
