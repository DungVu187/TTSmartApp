import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/notifications/data/models/notification_models.dart';
import 'package:ttsmart_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:ttsmart_mobile/features/notifications/presentation/controllers/notifications_controller.dart';

class _Repository implements NotificationRepository {
  int unreadCalls = 0;
  int readCalls = 0;
  int readAllCalls = 0;

  @override
  Future<NotificationPage> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) => Future.value(
    NotificationPage(
      items: [_notification],
      pageNumber: 1,
      pageSize: 20,
      totalCount: 1,
      totalPages: 1,
    ),
  );

  @override
  Future<int> getUnreadCount() async => ++unreadCalls;

  @override
  Future<void> markAllRead() async => readAllCalls++;

  @override
  Future<void> markRead(int notificationId) async => readCalls++;
}

final _notification = AppNotification(
  id: 1,
  eventType: 'order.created',
  stationId: 10,
  entityType: 'order',
  entityId: '1',
  title: 'New order',
  body: 'Body',
  occurredAtUtc: DateTime.utc(2026),
  createdAtUtc: DateTime.utc(2026),
  readAtUtc: null,
);

void main() {
  test('loads, marks read and stops its only polling timer on dispose', () {
    fakeAsync((async) {
      final repository = _Repository();
      final controller = NotificationsController(
        repository,
        pollingInterval: const Duration(seconds: 10),
      );
      controller.initialize();
      async.flushMicrotasks();
      expect(repository.unreadCalls, 1);

      controller.initialize();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
      expect(repository.unreadCalls, 2);

      controller.dispose();
      async.elapse(const Duration(seconds: 20));
      async.flushMicrotasks();
      expect(repository.unreadCalls, 2);
    });
  });

  test(
    'marks an individual notification and then all notifications read',
    () async {
      final repository = _Repository();
      final controller = NotificationsController(repository);
      await controller.load();
      await controller.markRead(_notification);
      expect(repository.readCalls, 1);
      expect(controller.unreadCount, 0);
      await controller.load();
      await controller.markAllRead();
      expect(repository.readAllCalls, 1);
      expect(controller.unreadCount, 0);
      controller.dispose();
    },
  );
}
