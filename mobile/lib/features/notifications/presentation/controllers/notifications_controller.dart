import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/notification_models.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository, {Duration? pollingInterval})
    : _pollingInterval = pollingInterval ?? _defaultPollingInterval;

  final NotificationRepository _repository;
  static const Duration _defaultPollingInterval = Duration(seconds: 45);
  final Duration _pollingInterval;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _isLoading = false;
  bool _isMarkingAllRead = false;
  bool _initialized = false;
  int _unreadCount = 0;
  List<AppNotification> _items = const <AppNotification>[];
  ApiException? _error;

  bool get isLoading => _isLoading;
  bool get isMarkingAllRead => _isMarkingAllRead;
  int get unreadCount => _unreadCount;
  List<AppNotification> get items => _items;
  ApiException? get error => _error;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    startPolling();
    await refreshUnreadCount();
  }

  void startPolling() {
    if (_pollTimer != null || _disposed) return;
    _pollTimer = Timer.periodic(_pollingInterval, (_) => refreshUnreadCount());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      if (_disposed) return;
      _unreadCount = count;
      notifyListeners();
    } on ApiException {
      // The explicit list screen displays retryable failures; polling stays silent.
    }
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repository.getNotifications();
      if (_disposed) return;
      _items = page.items;
      _unreadCount = page.items.where((item) => !item.isRead).length;
    } on ApiException catch (error) {
      if (!_disposed) _error = error;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await _repository.markRead(notification.id);
    if (_disposed) return;
    _items = _items
        .map(
          (item) => item.id == notification.id
              ? AppNotification(
                  id: item.id,
                  eventType: item.eventType,
                  companyId: item.companyId,
                  stationId: item.stationId,
                  entityType: item.entityType,
                  entityId: item.entityId,
                  title: item.title,
                  body: item.body,
                  payloadJson: item.payloadJson,
                  occurredAtUtc: item.occurredAtUtc,
                  createdAtUtc: item.createdAtUtc,
                  readAtUtc: DateTime.now().toUtc(),
                )
              : item,
        )
        .toList(growable: false);
    _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount).toInt();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    if (_isMarkingAllRead || _unreadCount == 0) return;
    _isMarkingAllRead = true;
    notifyListeners();
    try {
      await _repository.markAllRead();
      final now = DateTime.now().toUtc();
      _items = _items
          .map(
            (item) => item.isRead
                ? item
                : AppNotification(
                    id: item.id,
                    eventType: item.eventType,
                    companyId: item.companyId,
                    stationId: item.stationId,
                    entityType: item.entityType,
                    entityId: item.entityId,
                    title: item.title,
                    body: item.body,
                    payloadJson: item.payloadJson,
                    occurredAtUtc: item.occurredAtUtc,
                    createdAtUtc: item.createdAtUtc,
                    readAtUtc: now,
                  ),
          )
          .toList(growable: false);
      _unreadCount = 0;
    } finally {
      if (!_disposed) {
        _isMarkingAllRead = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
