enum AppNotificationType { information, order, warning }

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
}
