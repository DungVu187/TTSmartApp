import '../models/app_notification.dart';

abstract interface class NotificationsRepository {
  Future<List<AppNotificationItem>> getNotifications();
}

class MockNotificationsRepository implements NotificationsRepository {
  const MockNotificationsRepository();

  @override
  Future<List<AppNotificationItem>> getNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const <AppNotificationItem>[];
  }
}
