import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        isActive ? LucideIcons.circleCheck : LucideIcons.circlePause,
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
