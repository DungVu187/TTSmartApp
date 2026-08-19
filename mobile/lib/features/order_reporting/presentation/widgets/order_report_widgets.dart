import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/order_report_models.dart';

class OrderReportPartialWarning extends StatelessWidget {
  const OrderReportPartialWarning({
    super.key,
    required this.unavailableStationCount,
  });

  final int unavailableStationCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('order-report-partial-warning'),
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Không thể tải dữ liệu từ $unavailableStationCount trạm',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderReportMetricCard extends StatelessWidget {
  const OrderReportMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 160;
        final iconExtent = compact ? 36.0 : 42.0;
        return Card(
          color: accent.withValues(alpha: 0.035),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            side: BorderSide(color: accent.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconExtent,
                  height: iconExtent,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(compact ? 11 : 13),
                  ),
                  child: Icon(icon, size: compact ? 21 : 24, color: accent),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: accent,
                        fontSize: compact ? 20 : null,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? theme.textTheme.labelLarge
                              : theme.textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: compact ? 10 : null,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OrderReportItemCard extends StatelessWidget {
  const OrderReportItemCard({super.key, required this.item});

  final OrderReportItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đơn #${item.orderId}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _display(item.customerName, 'Chưa có khách hàng'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _DateBadge(value: item.orderedAtUtc),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _Metadata(
                  icon: Icons.factory_outlined,
                  label: _display(item.companyName, 'Chưa có công ty'),
                ),
                _Metadata(
                  icon: Icons.location_on_outlined,
                  label: item.stationDisplayName,
                ),
                _Metadata(
                  icon: Icons.apartment_outlined,
                  label: _display(item.projectName, 'Chưa có dự án'),
                ),
                _Metadata(
                  icon: Icons.science_outlined,
                  label: _display(
                    item.concreteGradeName,
                    'Chưa có mác bê tông',
                  ),
                ),
                _Metadata(
                  icon: Icons.badge_outlined,
                  label: _display(item.employeeName, 'Chưa gán nhân viên'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final ordered = _VolumeBox(
                  label: 'Khối lượng đặt',
                  value: formatOrderReportVolume(item.orderedVolume),
                  color: theme.colorScheme.primary,
                );
                final produced = _VolumeBox(
                  label: 'Đã sản xuất',
                  value: formatOrderReportVolume(item.producedVolume),
                  color: AppColors.success,
                );
                return Row(
                  children: [
                    Expanded(child: ordered),
                    const SizedBox(width: 8),
                    Expanded(child: produced),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.value});

  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value == null ? 'Chưa có ngày' : formatVietnamOrderDateTime(value!),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeBox extends StatelessWidget {
  const _VolumeBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$value m³',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String formatOrderReportVolume(num? value) {
  if (value == null) return '—';
  final text = value.toStringAsFixed(1);
  final parts = text.split('.');
  final integer = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < integer.length; index++) {
    if (index > 0 && (integer.length - index) % 3 == 0) buffer.write('.');
    buffer.write(integer[index]);
  }
  if (parts.length == 1) return buffer.toString();
  return '${buffer.toString()},${parts.last}';
}

String formatVietnamOrderDateTime(DateTime value) {
  final vietnam = value.toUtc().add(const Duration(hours: 7));
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(vietnam.day)}/${twoDigits(vietnam.month)} '
      '${twoDigits(vietnam.hour)}:${twoDigits(vietnam.minute)}';
}

String _display(String? value, String fallback) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}
