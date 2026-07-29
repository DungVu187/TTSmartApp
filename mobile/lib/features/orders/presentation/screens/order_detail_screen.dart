import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/order_models.dart';
import '../widgets/order_widgets.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.loadDetails,
  });

  final OrderSummary order;
  final Future<OrderDetails> Function(String id) loadDetails;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(order.code)),
      body: SafeArea(
        child: FutureBuilder<OrderDetails>(
          future: loadDetails(order.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return AppContent(
                maxWidth: 760,
                child: const ErrorPanel(
                  message: 'Không thể tải chi tiết đơn hàng.',
                ),
              );
            }
            final details = snapshot.data!;
            return ListView(
              children: [
                AppContent(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      details.summary.customerName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OrderStatusBadge(
                                    status: details.summary.status,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${details.summary.stationName} · '
                                '${details.summary.concreteGrade}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const AppSectionHeader(title: 'Thông tin giao hàng'),
                      const SizedBox(height: 10),
                      Card(
                        child: Column(
                          children: [
                            OrderDetailRow(
                              label: 'Thời gian',
                              value: formatLocalDateTime(
                                details.summary.scheduledAt,
                              ),
                              icon: Icons.schedule_outlined,
                            ),
                            const Divider(),
                            OrderDetailRow(
                              label: 'Khối lượng',
                              value: '${details.summary.quantity} m³',
                              icon: Icons.scale_outlined,
                            ),
                            const Divider(),
                            OrderDetailRow(
                              label: 'Đã giao',
                              value: '${details.summary.deliveredQuantity} m³',
                              icon: Icons.local_shipping_outlined,
                            ),
                            const Divider(),
                            OrderDetailRow(
                              label: 'Địa điểm',
                              value: details.deliveryAddress,
                              icon: Icons.location_on_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const AppSectionHeader(title: 'Yêu cầu kỹ thuật'),
                      const SizedBox(height: 10),
                      Card(
                        child: Column(
                          children: [
                            OrderDetailRow(
                              label: 'Độ sụt',
                              value: details.slump,
                              icon: Icons.science_outlined,
                            ),
                            const Divider(),
                            OrderDetailRow(
                              label: 'Hình thức bơm',
                              value: details.pumpType,
                              icon: Icons.construction_outlined,
                            ),
                            const Divider(),
                            OrderDetailRow(
                              label: 'Liên hệ',
                              value:
                                  '${details.contactName}\n${details.contactPhone}',
                              icon: Icons.contact_phone_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const AppSectionHeader(title: 'Ghi chú'),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(details.note),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
