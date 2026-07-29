import 'package:flutter/foundation.dart';

import '../../data/models/app_notification.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository);

  final NotificationsRepository _repository;

  List<AppNotificationItem> _items = const <AppNotificationItem>[];
  String? _errorMessage;
  bool _isLoading = false;
  bool _initialized = false;

  List<AppNotificationItem> get items => _items;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _items = await _repository.getNotifications();
    } catch (_) {
      _errorMessage = 'Không thể tải thông báo. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
