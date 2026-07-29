import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/app_notification.dart';
import '../controllers/notifications_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.controller});

  final NotificationsController controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => RefreshIndicator(
            onRefresh: widget.controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [AppContent(maxWidth: 760, child: _buildContent())],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.controller.isLoading && widget.controller.items.isEmpty) {
      return const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.controller.errorMessage != null) {
      return ErrorPanel(
        message: widget.controller.errorMessage!,
        onRetry: widget.controller.refresh,
      );
    }
    if (widget.controller.items.isEmpty) {
      return const Card(
        child: AppEmptyState(
          icon: Icons.notifications_none,
          title: 'Chưa có thông báo',
          message:
              'Thông báo về đơn hàng và vận hành sẽ xuất hiện tại đây khi backend được kết nối.',
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (
            var index = 0;
            index < widget.controller.items.length;
            index++
          ) ...[
            if (index > 0) const Divider(),
            _NotificationTile(item: widget.controller.items[index]),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final AppNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      minTileHeight: 84,
      leading: CircleAvatar(
        child: Icon(switch (item.type) {
          AppNotificationType.information => Icons.info_outline,
          AppNotificationType.order => Icons.receipt_long_outlined,
          AppNotificationType.warning => Icons.warning_amber_outlined,
        }),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
        ),
      ),
      subtitle: Text('${item.message}\n${formatLocalDateTime(item.createdAt)}'),
      isThreeLine: true,
    );
  }
}
