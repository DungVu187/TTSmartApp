import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/notification_models.dart';

abstract interface class NotificationRepository {
  Future<NotificationPage> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  });
  Future<int> getUnreadCount();
  Future<void> markRead(int notificationId);
  Future<void> markAllRead();
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<NotificationPage> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    if (pageNumber < 1 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Trang thông báo không hợp lệ.');
    }
    final response = await _apiClient.get(
      '/api/notifications',
      query: <String, Object?>{'pageNumber': pageNumber, 'pageSize': pageSize},
    );
    try {
      return NotificationPage.fromJson(response);
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/api/notifications/unread-count');
    try {
      return requireInt(
        requireJsonObject(response, 'unread notification count'),
        'count',
      );
    } catch (_) {
      throw ApiException.invalidResponse('Số thông báo chưa đọc không hợp lệ.');
    }
  }

  @override
  Future<void> markRead(int notificationId) async {
    await _apiClient.post('/api/notifications/$notificationId/read');
  }

  @override
  Future<void> markAllRead() async {
    await _apiClient.post('/api/notifications/read-all');
  }
}
