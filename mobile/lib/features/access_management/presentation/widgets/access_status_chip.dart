import 'package:flutter/material.dart';

class AccessStatusChip extends StatelessWidget {
  const AccessStatusChip({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isActive
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = isActive
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
        size: 18,
        color: foreground,
      ),
      label: Text(isActive ? 'Đang dùng' : 'Đang tắt'),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      backgroundColor: background,
      side: BorderSide.none,
    );
  }
}
