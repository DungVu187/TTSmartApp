import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/notification_models.dart';
import '../controllers/notifications_controller.dart';
import '../widgets/notification_list_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.controller,
    required this.onOpenOrder,
  });
  final NotificationsController controller;
  final ValueChanged<AppNotification> onOpenOrder;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controller.load(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo'),
      actions: [
        TextButton(
          onPressed:
              widget.controller.unreadCount == 0 ||
                  widget.controller.isMarkingAllRead
              ? null
              : widget.controller.markAllRead,
          child: const Text('Đánh dấu tất cả đã đọc'),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading && widget.controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.controller.error != null &&
            widget.controller.items.isEmpty) {
          return ErrorPanel(
            message: widget.controller.error!.message,
            onRetry: widget.controller.load,
          );
        }
        if (widget.controller.items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.notifications_none,
            title: 'Chưa có thông báo',
            message: 'Các thông báo mới sẽ xuất hiện tại đây.',
          );
        }
        return RefreshIndicator(
          onRefresh: widget.controller.load,
          child: ListView.separated(
            itemCount: widget.controller.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = widget.controller.items[index];
              return NotificationListItem(
                notification: item,
                onTap: () async {
                  await widget.controller.markRead(item);
                  if (item.eventType == 'order.created' && context.mounted) {
                    widget.onOpenOrder(item);
                  }
                },
              );
            },
          ),
        );
      },
    ),
  );
}
