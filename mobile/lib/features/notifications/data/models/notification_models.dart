import '../../../../core/network/json_helpers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventType,
    required this.stationId,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.occurredAtUtc,
    required this.createdAtUtc,
    required this.readAtUtc,
    this.companyId,
    this.payloadJson,
  });

  factory AppNotification.fromJson(Object? source) {
    final json = requireJsonObject(source, 'thông báo');
    return AppNotification(
      id: requireInt(json, 'id'),
      eventType: requireString(json, 'eventType'),
      companyId: optionalInt(json, 'companyId'),
      stationId: requireInt(json, 'stationId'),
      entityType: requireString(json, 'entityType'),
      entityId: requireString(json, 'entityId'),
      title: requireString(json, 'title'),
      body: requireString(json, 'body'),
      payloadJson: optionalString(json, 'payloadJson'),
      occurredAtUtc: requireUtcDateTime(json, 'occurredAtUtc'),
      createdAtUtc: requireUtcDateTime(json, 'createdAtUtc'),
      readAtUtc: optionalUtcDateTime(json, 'readAtUtc'),
    );
  }

  final int id;
  final String eventType;
  final int? companyId;
  final int stationId;
  final String entityType;
  final String entityId;
  final String title;
  final String body;
  final String? payloadJson;
  final DateTime occurredAtUtc;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;

  bool get isRead => readAtUtc != null;
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory NotificationPage.fromJson(Object? source) {
    final json = requireJsonObject(source, 'trang thông báo');
    return NotificationPage(
      items: requireJsonList(
        json['items'],
        'items thông báo',
      ).map(AppNotification.fromJson).toList(growable: false),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
    );
  }

  final List<AppNotification> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
