import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/app_dependencies.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/notifications/data/models/notification_models.dart';
import 'package:ttsmart_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/models/order_report_models.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/shell/presentation/screens/app_shell.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';

import '../test/support/empty_reports_repository.dart';
import 'fixtures_access.dart';
import 'fixtures_org.dart';
import 'fixtures_shell.dart';
import 'harness.dart';

/// Non-admin user with a single station: the Orders tab loads by itself.
class _SingleStationOrders extends VisualOrderReportRepository {
  @override
  Future<List<OrderReportStation>> getStations({int? companyId}) async => [
    VisualOrderReportRepository.stations.first,
  ];
}

class _MixedNotifications extends VisualNotificationRepository {
  @override
  Future<NotificationPage> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final page = await super.getNotifications(
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    final at = DateTime.utc(2026, 9, 21, 1);
    final items = [
      ...page.items,
      AppNotification(
        id: 100,
        eventType: 'system.updated',
        stationId: 10,
        entityType: 'system',
        entityId: '1',
        title: 'Cập nhật hệ thống',
        body: 'Quyền truy cập đã được cập nhật.',
        occurredAtUtc: at,
        createdAtUtc: at,
        readAtUtc: null,
      ),
    ];
    return NotificationPage(
      items: items,
      pageNumber: 1,
      pageSize: pageSize,
      totalCount: items.length,
      totalPages: 1,
    );
  }
}

AppFeatureRepositories _repositories(
  ApiClient api, {
  OrderReportRepository? orders,
  NotificationRepository? notifications,
}) => AppFeatureRepositories(
  home: VisualHomeRepository(),
  notifications: notifications ?? VisualNotificationRepository(),
  mixDesigns: ApiMixDesignRepository(api),
  materialReports: ApiMaterialReportRepository(api),
  orderReports: orders ?? VisualOrderReportRepository(),
  reports: const EmptyReportsRepository(),
  companies: VisualCompanyRepository(),
  stations: ApiStationRepository(api),
  weighStations: ApiWeighStationRepository(api),
);

Future<void> _pumpShell(
  WidgetTester tester, {
  bool admin = true,
  OrderReportRepository? orders,
  NotificationRepository? notifications,
}) async {
  usePhoneFrame(tester);
  final api = visualApiClient();
  final controller = VisualAppController(api, isAdmin: admin);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    visualApp(
      controller,
      AppShell(
        repositories: _repositories(
          api,
          orders: orders,
          notifications: notifications,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualFonts);

  testWidgets('01 login', (tester) async {
    usePhoneFrame(tester);
    final controller = VisualAppController(offlineApiClient());
    addTearDown(controller.dispose);
    await tester.pumpWidget(visualApp(controller, const LoginScreen()));
    await tester.pumpAndSettle();
    await snap('screens_01_login');
  });

  testWidgets('02 home', (tester) async {
    await _pumpShell(tester);
    await snap('screens_02_home');
  });

  testWidgets('03 orders', (tester) async {
    await _pumpShell(tester, admin: false, orders: _SingleStationOrders());
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-orders')));
    await tester.pumpAndSettle();
    await snap('screens_03_orders');
    // Figma 03b: the whole order opens from its row.
    await tester.tap(find.text('Công ty CP Xây dựng Hòa Bình'));
    await tester.pumpAndSettle();
    await snap('screens_03b_order_detail');
  });

  testWidgets('03 orders SupAdmin filters', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-orders')));
    await tester.pumpAndSettle();
    await snap('screens_03_orders_admin');
  });

  testWidgets('04 notifications', (tester) async {
    await _pumpShell(tester, notifications: _MixedNotifications());
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    await snap('screens_04_notifications');
  });

  testWidgets('05 more', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-more')));
    await tester.pumpAndSettle();
    await snap('screens_05_more');
  });
}
