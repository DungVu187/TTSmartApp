import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../data/models/order_models.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      OrderStatus.pending => (AppColors.warning, const Color(0xFFFFEBC8)),
      OrderStatus.mixing => (AppColors.brandBlue, const Color(0xFFDCEBFA)),
      OrderStatus.delivering => (
        const Color(0xFF6853B8),
        const Color(0xFFEAE4FF),
      ),
      OrderStatus.completed => (AppColors.success, const Color(0xFFDDF4EC)),
      OrderStatus.canceled => (AppColors.danger, const Color(0xFFFBE0E3)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = order.quantity <= 0
        ? 0.0
        : (order.deliveredQuantity / order.quantity).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.code,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.customerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _OrderMeta(
                    icon: Icons.factory_outlined,
                    text: order.stationName,
                  ),
                  _OrderMeta(
                    icon: Icons.science_outlined,
                    text: order.concreteGrade,
                  ),
                  _OrderMeta(
                    icon: Icons.schedule_outlined,
                    text: _shortDateTime(order.scheduledAt),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đã giao ${_quantity(order.deliveredQuantity)} / '
                      '${_quantity(order.quantity)} m³',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDateTime(DateTime value) {
    final formatted = formatLocalDateTime(value);
    return formatted.substring(formatted.length - 5);
  }

  String _quantity(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class OrderDetailRow extends StatelessWidget {
  const OrderDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
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
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
