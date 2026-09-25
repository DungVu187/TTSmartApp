// Sample data copied from the Figma frames (Home, Orders, Notifications).
import 'package:ttsmart_mobile/core/models/data_scope.dart';
import 'package:ttsmart_mobile/core/models/time_range_preset.dart';
import 'package:ttsmart_mobile/features/home/data/models/dashboard_models.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';
import 'package:ttsmart_mobile/features/notifications/data/models/notification_models.dart';
import 'package:ttsmart_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/models/order_report_models.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';

import 'fixtures_access.dart';

class VisualHomeRepository implements HomeRepository {
  static const _scopes = <DashboardScope>[
    DashboardScope(
      keyName: 'company-3',
      label: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
      type: DataScopeType.company,
      companyId: 3,
    ),
    DashboardScope(
      keyName: 'station-10',
      label: 'Trạm Hà Nam',
      type: DataScopeType.station,
      companyId: 3,
      branchId: 10,
      description: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
    ),
    DashboardScope(
      keyName: 'station-11',
      label: 'Trạm Ninh Bình',
      type: DataScopeType.station,
      companyId: 3,
      branchId: 11,
      description: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
    ),
  ];

  @override
  Future<List<DashboardScope>> getAvailableScopes() async => _scopes;

  /// Goes through [ApiHomeRepository] (labels, number parsing) with a JSON
  /// body shaped like the server's; "Hôm nay" comes back per hour like on the
  /// phone (00H…23H).
  @override
  Future<DashboardSnapshot> getDashboard({
    required DashboardScope? scope,
    required TimeRangePreset timeRange,
  }) {
    final hourly = timeRange.usesHourlyBuckets;
    const dayValues = [
      300, 320, 340, 360, 380, 400, 420, 440, 430, 420, //
      410, 420, 440, 460, 450, 440, 450, 470, 490, 500, //
      510, 505, 500, 505, 510, 515, 520, 522, 520, 518,
    ];
    const hourValues = [
      120, 118, 110, 96, 90, 160, 780, 1450, 1380, 1260, 1190, 520, //
      60, 40, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
    ];
    final body = <String, Object?>{
      'updatedAt': '2026-09-21T02:40:00Z',
      'totalMixedVolume': 12480,
      'orderCount': 128,
      'concreteGradeCount': 14,
      'mixerTruckCount': 36,
      'salesEmployeeCount': 9,
      'volumePoints': [
        if (hourly)
          for (var hour = 0; hour < 24; hour++)
            {
              'label': '${hour.toString().padLeft(2, '0')}H',
              'mixedVolume': hourValues[hour],
            }
        else
          for (var day = 1; day <= 30; day++)
            {
              'label': day.toString().padLeft(2, '0'),
              'mixedVolume': dayValues[day - 1],
            },
      ],
      'stations': [
        {
          'branchId': 10,
          'stationName': 'Trạm Hà Nam',
          'isAvailable': true,
          'orderCount': 96,
          'mixedVolume': 9800,
          'mixerTruckCount': 28,
        },
        {
          'branchId': 11,
          'stationName': 'Trạm Ninh Bình',
          'isAvailable': false,
          'orderCount': 0,
          'mixedVolume': 0,
          'mixerTruckCount': 0,
        },
        {
          'branchId': 12,
          'stationName': 'Trạm Phủ Lý 2',
          'isAvailable': false,
          'orderCount': 0,
          'mixedVolume': 0,
          'mixerTruckCount': 0,
        },
      ],
      'unavailableStationCount': 2,
    };
    final api = visualApiClient({r'GET /api/dashboard': (_) => body});
    return ApiHomeRepository(
      api,
      now: () => DateTime(2026, 9, 21, 9, 40),
    ).getDashboard(scope: scope, timeRange: timeRange);
  }
}

class VisualNotificationRepository implements NotificationRepository {
  static final _items = <AppNotification>[
    _notification(
      1,
      'Đơn hàng mới #10482',
      'Công ty CP Xây dựng Hòa Bình đặt 120 m³ M300 tại Trạm Hà Nam.',
      DateTime.utc(2026, 9, 21, 1, 15),
    ),
    _notification(
      2,
      'Đơn hàng mới #10481',
      'Cty TNHH Thương mại Minh Phát đặt 45 m³ M250 tại Trạm Hà Nam.',
      DateTime.utc(2026, 9, 21, 0, 52),
    ),
    _notification(
      3,
      'Đơn hàng mới #10480',
      'Công ty Xây lắp Sông Đà đặt 30 m³ M200 tại Trạm Ninh Bình.',
      DateTime.utc(2026, 9, 20, 23, 30),
    ),
    _notification(
      4,
      'Đơn hàng mới #10479',
      'Cty TNHH Minh Phát đặt 60 m³ M250 tại Trạm Hà Nam.',
      DateTime.utc(2026, 9, 20, 9, 20),
      read: true,
    ),
    _notification(
      5,
      'Đơn hàng mới #10478',
      'Công ty CP Đầu tư Phủ Lý đặt 18 m³ M300 tại Trạm Hà Nam.',
      DateTime.utc(2026, 9, 20, 2, 5),
      read: true,
    ),
  ];

  static AppNotification _notification(
    int id,
    String title,
    String body,
    DateTime at, {
    bool read = false,
  }) => AppNotification(
    id: id,
    eventType: 'order.created',
    stationId: 10,
    entityType: 'order',
    entityId: '${10483 - id}',
    title: title,
    body: body,
    occurredAtUtc: at,
    createdAtUtc: at,
    readAtUtc: read ? at : null,
  );

  @override
  Future<NotificationPage> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async => NotificationPage(
    items: _items,
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: _items.length,
    totalPages: 1,
  );

  @override
  Future<int> getUnreadCount() async => 3;

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(int notificationId) async {}
}

class VisualOrderReportRepository implements OrderReportRepository {
  static const stations = <OrderReportStation>[
    OrderReportStation(
      id: 10,
      companyId: 3,
      name: 'Trạm Hà Nam',
      typeTram: 1,
      companyName: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
      code: null,
    ),
    OrderReportStation(
      id: 11,
      companyId: 3,
      name: 'Trạm Ninh Bình',
      typeTram: 1,
      companyName: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
      code: null,
    ),
  ];

  static final _items = <OrderReportItem>[
    OrderReportItem(
      orderId: 10482,
      branchId: 10,
      stationName: 'Trạm Hà Nam',
      customerName: 'Công ty CP Xây dựng Hòa Bình',
      projectName: 'KĐT Phủ Lý',
      concreteGradeName: 'M300',
      orderedVolume: 120,
      producedVolume: 96,
      orderedAtUtc: DateTime.utc(2026, 9, 21, 1, 15),
      employeeName: 'Nguyễn Văn A',
    ),
    OrderReportItem(
      orderId: 10481,
      branchId: 10,
      stationName: 'Trạm Hà Nam',
      customerName: 'Cty TNHH Thương mại Minh Phát',
      projectName: 'Cầu Sông Đáy',
      concreteGradeName: 'M250',
      orderedVolume: 45,
      producedVolume: 45,
      orderedAtUtc: DateTime.utc(2026, 9, 21, 0, 40),
      employeeName: null,
    ),
    OrderReportItem(
      orderId: 10480,
      branchId: 10,
      stationName: 'Trạm Hà Nam',
      customerName: 'Công ty Xây lắp Sông Đà',
      projectName: 'Nhà máy Đồng Văn',
      concreteGradeName: 'M200',
      orderedVolume: 30,
      producedVolume: 12,
      orderedAtUtc: DateTime.utc(2026, 9, 20, 9, 5),
      employeeName: 'Trần Thị Lan',
    ),
  ];

  @override
  Future<List<OrderReportStation>> getStations({int? companyId}) async =>
      stations;

  @override
  Future<List<OrderReportEmployee>> getEmployees({
    required int branchId,
    int? companyId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async => const [
    OrderReportEmployee(name: 'Nguyễn Văn A'),
    OrderReportEmployee(name: 'Trần Thị Lan'),
  ];

  @override
  Future<OrderReportPage> search(OrderReportQuery query) async =>
      OrderReportPage(
        items: _items,
        pageNumber: 1,
        pageSize: 10,
        totalCount: 128,
        totalPages: 1,
        totalOrderedVolume: 3940,
        totalProducedVolume: 3612,
        stationSummaries: const [],
        isPartial: false,
        successfulStationCount: 1,
        unavailableStationCount: 0,
        unavailableStations: const [],
      );
}
