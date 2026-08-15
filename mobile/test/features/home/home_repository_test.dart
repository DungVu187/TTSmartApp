import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/models/data_scope.dart';
import 'package:ttsmart_mobile/core/models/time_range_preset.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/home/data/models/dashboard_models.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';

void main() {
  test('ApiHomeRepository maps all dashboard time presets', () async {
    final requests = <TimeRangePreset, Uri>{};
    var currentPreset = TimeRangePreset.today;
    final client = MockClient((request) async {
      requests[currentPreset] = request.url;
      return http.Response(
        jsonEncode(<String, Object?>{
          'updatedAt': '2026-08-13T01:00:00Z',
          'orderCount': 0,
          'concreteGradeCount': 0,
          'mixerTruckCount': 0,
          'salesEmployeeCount': 0,
          'totalMixedVolume': 0,
          'volumePoints': <Object?>[],
          'stations': <Object?>[],
          'unavailableStationCount': 0,
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: client,
    )..accessToken = 'test-token';
    final repository = ApiHomeRepository(
      apiClient,
      now: () => DateTime(2026, 8, 13, 9),
    );
    for (final preset in TimeRangePreset.values) {
      currentPreset = preset;
      await repository.getDashboard(scope: null, timeRange: preset);
    }

    void expectRange(
      TimeRangePreset preset,
      String from,
      String to,
      String interval,
    ) {
      final query = requests[preset]!.queryParameters;
      expect(query, containsPair('from', from));
      expect(query, containsPair('to', to));
      expect(query, containsPair('interval', interval));
    }

    expectRange(
      TimeRangePreset.today,
      '2026-08-13T00:00:00+07:00',
      '2026-08-14T00:00:00+07:00',
      'hour',
    );
    expectRange(
      TimeRangePreset.yesterday,
      '2026-08-12T00:00:00+07:00',
      '2026-08-13T00:00:00+07:00',
      'hour',
    );
    expectRange(
      TimeRangePreset.thisWeek,
      '2026-08-10T00:00:00+07:00',
      '2026-08-17T00:00:00+07:00',
      'day',
    );
    expectRange(
      TimeRangePreset.lastWeek,
      '2026-08-03T00:00:00+07:00',
      '2026-08-10T00:00:00+07:00',
      'day',
    );
    expectRange(
      TimeRangePreset.thisMonth,
      '2026-08-01T00:00:00+07:00',
      '2026-09-01T00:00:00+07:00',
      'day',
    );
    expectRange(
      TimeRangePreset.lastMonth,
      '2026-07-01T00:00:00+07:00',
      '2026-08-01T00:00:00+07:00',
      'day',
    );
    final defaultQuery = requests[TimeRangePreset.today]!.queryParameters;
    expect(defaultQuery, isNot(contains('companyId')));
    expect(defaultQuery, isNot(contains('branchId')));

    apiClient.close();
  });

  test('ApiHomeRepository gửi đúng bộ lọc và cộng biểu đồ M3METRON', () async {
    Uri? dashboardUri;
    final client = MockClient((request) async {
      if (request.url.path == '/api/dashboard/scopes') {
        return http.Response(
          jsonEncode(<Object?>[
            <String, Object?>{
              'keyName': 'station-10',
              'label': 'Trạm 10',
              'type': 'station',
              'companyId': 1,
              'branchId': 10,
              'description': 'Công ty 1',
            },
          ]),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      dashboardUri = request.url;
      return http.Response(
        jsonEncode(<String, Object?>{
          'updatedAt': '2026-08-12T07:00:00Z',
          'orderCount': 2,
          'concreteGradeCount': 1,
          'mixerTruckCount': 1,
          'salesEmployeeCount': 1,
          'totalMixedVolume': 5.2,
          'volumePoints': <Object?>[
            <String, Object?>{
              'startedAt': '2026-08-11T23:00:00Z',
              'label': '06H',
              'mixedVolume': 2.6,
            },
            <String, Object?>{
              'startedAt': '2026-08-12T00:00:00Z',
              'label': '07H',
              'mixedVolume': 2.6,
            },
          ],
          'stations': <Object?>[
            <String, Object?>{
              'branchId': 10,
              'companyId': 1,
              'companyName': 'Công ty 1',
              'stationName': 'Trạm 10',
              'isAvailable': true,
              'orderCount': 2,
              'mixedVolume': 5.2,
              'mixerTruckCount': 1,
            },
          ],
          'unavailableStationCount': 0,
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: client,
    )..accessToken = 'test-token';
    final repository = ApiHomeRepository(
      apiClient,
      now: () => DateTime(2026, 8, 12, 14, 30),
    );

    final scopes = await repository.getAvailableScopes();
    final snapshot = await repository.getDashboard(
      scope: scopes.single,
      timeRange: TimeRangePreset.today,
    );

    expect(scopes.single, isA<DashboardScope>());
    expect(scopes.single.type, DataScopeType.station);
    expect(dashboardUri?.queryParameters, containsPair('companyId', '1'));
    expect(dashboardUri?.queryParameters, containsPair('branchId', '10'));
    expect(
      dashboardUri?.queryParameters,
      containsPair('from', '2026-08-12T00:00:00+07:00'),
    );
    expect(
      dashboardUri?.queryParameters,
      containsPair('to', '2026-08-13T00:00:00+07:00'),
    );
    expect(dashboardUri?.queryParameters, containsPair('interval', 'hour'));
    expect(snapshot.totalMixedVolume, 5.2);
    expect(snapshot.chartLabels, <String>['06H', '07H']);
    expect(snapshot.chartValues.reduce((first, second) => first + second), 5.2);
    expect(snapshot.metrics.first.value, '2');
    expect(
      snapshot.metrics
          .firstWhere((metric) => metric.type == DashboardMetricType.orders)
          .caption,
      'Hôm nay',
    );
    expect(
      snapshot.metrics
          .firstWhere(
            (metric) => metric.type == DashboardMetricType.concreteGrades,
          )
          .caption,
      'Hôm nay',
    );
    expect(
      snapshot.metrics
          .firstWhere(
            (metric) => metric.type == DashboardMetricType.mixerTrucks,
          )
          .caption,
      'Hôm nay',
    );
    expect(
      snapshot.metrics
          .firstWhere(
            (metric) => metric.type == DashboardMetricType.salesWithOrders,
          )
          .caption,
      'Hôm nay',
    );
    expect(snapshot.stations.single.mixedVolume, 5.2);
    expect(snapshot.stations.single.mixerTruckCount, 1);

    final yesterdaySnapshot = await repository.getDashboard(
      scope: scopes.single,
      timeRange: TimeRangePreset.yesterday,
    );
    expect(
      yesterdaySnapshot.metrics
          .firstWhere(
            (metric) => metric.type == DashboardMetricType.salesWithOrders,
          )
          .caption,
      'Hôm qua',
    );

    apiClient.close();
  });
}
