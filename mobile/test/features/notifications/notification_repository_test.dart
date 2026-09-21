import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/notifications/data/models/notification_models.dart';
import 'package:ttsmart_mobile/features/notifications/data/repositories/notification_repository.dart';

http.Response _response(Object value) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), 200);

void main() {
  test('parses notification DTO and calls notification endpoints', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('unread-count')) {
          return _response({'count': 2});
        }
        if (request.method == 'GET') {
          return _response({
            'items': [
              {
                'id': 1,
                'eventType': 'order.created',
                'companyId': 2,
                'stationId': 10,
                'entityType': 'order',
                'entityId': '125',
                'title': 'New order',
                'body': 'Station order',
                'payloadJson': '{"stationId":10,"orderId":125}',
                'occurredAtUtc': '2026-08-24T00:00:00Z',
                'createdAtUtc': '2026-08-24T00:00:00Z',
                'readAtUtc': null,
              },
            ],
            'pageNumber': 1,
            'pageSize': 20,
            'totalCount': 1,
            'totalPages': 1,
          });
        }
        return _response(<String, Object?>{});
      }),
    )..accessToken = 'token';
    final repository = ApiNotificationRepository(client);

    final page = await repository.getNotifications();
    expect(page.items.single.eventType, 'order.created');
    expect(page.items.single.stationId, 10);
    expect(page.items.single.isRead, isFalse);
    expect(await repository.getUnreadCount(), 2);
    await repository.markRead(1);
    await repository.markAllRead();

    expect(requests.map((request) => request.url.path), [
      '/api/notifications',
      '/api/notifications/unread-count',
      '/api/notifications/1/read',
      '/api/notifications/read-all',
    ]);
    expect(requests[0].url.queryParameters, {
      'pageNumber': '1',
      'pageSize': '20',
    });
  });

  test('notification DTO rejects an invalid UTC timestamp', () {
    expect(
      () => AppNotification.fromJson({
        'id': 1,
        'eventType': 'order.created',
        'stationId': 10,
        'entityType': 'order',
        'entityId': '1',
        'title': 'Title',
        'body': 'Body',
        'occurredAtUtc': 'not-a-date',
        'createdAtUtc': '2026-08-24T00:00:00Z',
        'readAtUtc': null,
      }),
      throwsFormatException,
    );
  });
}
