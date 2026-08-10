import 'package:flutter/material.dart';

import '../../data/models/station_models.dart';

class StationTypeChip extends StatelessWidget {
  const StationTypeChip({super.key, required this.type});

  final StationType? type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isScale = type == StationType.scale;
    final isKnown = type != null;
    final foreground = switch (type) {
      StationType.scale => colors.onSecondaryContainer,
      StationType.mixing => colors.onPrimaryContainer,
      null => colors.onSurfaceVariant,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(stationTypeIcon(type), size: 17, color: foreground),
      label: Text(type?.label ?? 'Chưa xác định'),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      backgroundColor: !isKnown
          ? colors.surfaceContainerHighest
          : isScale
          ? colors.secondaryContainer
          : colors.primaryContainer,
      side: BorderSide.none,
    );
  }
}

class StationStatusChip extends StatelessWidget {
  const StationStatusChip({super.key, required this.isDeleted});

  final bool isDeleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isDeleted
        ? colors.onSurfaceVariant
        : colors.onPrimaryContainer;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isDeleted ? Icons.delete_outline : Icons.check_circle_outline,
        size: 17,
        color: foreground,
      ),
      label: Text(isDeleted ? 'Đã xóa' : 'Đang hoạt động'),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      backgroundColor: isDeleted
          ? colors.surfaceContainerHighest
          : colors.primaryContainer,
      side: BorderSide.none,
    );
  }
}

class StationSection extends StatelessWidget {
  const StationSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.description,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: child,
        ),
      ],
    );
  }
}

class StationInfoRow extends StatelessWidget {
  const StationInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = constraints.maxWidth < 360 ? 96.0 : 116.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  normalized,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StationListCard extends StatelessWidget {
  const StationListCard({
    super.key,
    required this.station,
    this.isDeleted = false,
    this.onTap,
    this.onMenu,
  });

  final StationListItem station;
  final bool isDeleted;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = onTap != null;
    return Material(
      color: isDeleted
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  stationTypeIcon(station.type),
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (station.phone?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              station.phone!,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StationTypeChip(type: station.type),
                        if (isDeleted) const StationStatusChip(isDeleted: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (onMenu != null)
                IconButton(
                  tooltip: 'Thao tác',
                  onPressed: onMenu,
                  icon: const Icon(Icons.more_vert),
                )
              else if (isInteractive)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatStationDate(DateTime? value) {
  if (value == null) return 'Chưa có';
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String stationPasswordStatus(String value) =>
    value.trim().isEmpty ? 'Chưa thiết lập' : 'Đã thiết lập';

IconData stationTypeIcon(StationType? type) => switch (type) {
  StationType.scale => Icons.scale_outlined,
  StationType.mixing => Icons.factory_outlined,
  null => Icons.help_outline,
};
