import 'package:flutter/material.dart';

import '../../data/models/notification_models.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    super.key,
    required this.notification,
    required this.onTap,
  });
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: notification.isRead
          ? null
          : Theme.of(context).colorScheme.primaryContainer,
      child: const Icon(Icons.receipt_long_outlined),
    ),
    title: Text(
      notification.title,
      style: TextStyle(
        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w700,
      ),
    ),
    subtitle: Text(
      notification.body,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: notification.isRead ? null : const Icon(Icons.circle, size: 10),
    onTap: onTap,
  );
}
