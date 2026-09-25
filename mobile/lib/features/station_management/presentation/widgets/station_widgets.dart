import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';

import '../../data/models/station_models.dart';

/// "Trạm trộn" (blue) / "Trạm cân" (violet) tag with the type icon.
class StationTypeChip extends StatelessWidget {
  const StationTypeChip({super.key, required this.type});

  final StationType? type;

  @override
  Widget build(BuildContext context) => AppTag(
    label: type?.label ?? 'Chưa xác định',
    icon: stationTypeIcon(type),
    tone: stationTypeTone(type),
  );
}

class StationStatusChip extends StatelessWidget {
  const StationStatusChip({super.key, required this.isDeleted});

  final bool isDeleted;

  @override
  Widget build(BuildContext context) => AppTag(
    label: isDeleted ? 'Đã xóa' : 'Đang hoạt động',
    icon: isDeleted ? Icons.delete_outline_rounded : Icons.check_rounded,
    tone: isDeleted ? AppTone.neutral : AppTone.success,
  );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: GroupLabel(title)),
            ?trailing,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(
            description!,
            style: TextStyle(color: context.palette.text2, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
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
    return FieldRow(label: label, value: normalized);
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

AppTone stationTypeTone(StationType? type) => switch (type) {
  StationType.scale => AppTone.violet,
  StationType.mixing => AppTone.primary,
  null => AppTone.neutral,
};

IconData stationTypeIcon(StationType? type) => switch (type) {
  StationType.scale => Icons.balance_outlined,
  StationType.mixing => Icons.factory_outlined,
  null => Icons.help_outline,
};
