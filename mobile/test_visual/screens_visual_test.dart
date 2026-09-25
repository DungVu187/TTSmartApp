import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/app_dependencies.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
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

AppFeatureRepositories _repositories(
  ApiClient api, {
  OrderReportRepository? orders,
}) => AppFeatureRepositories(
  home: VisualHomeRepository(),
  notifications: VisualNotificationRepository(),
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
}) async {
  usePhoneFrame(tester);
  final api = visualApiClient();
  final controller = VisualAppController(api, isAdmin: admin);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    visualApp(
      controller,
      AppShell(repositories: _repositories(api, orders: orders)),
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
  });

  testWidgets('04 notifications', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    await snap('screens_04_notifications');
  });

  testWidgets('06 system', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-system')));
    await tester.pumpAndSettle();
    await snap('screens_06_system');
  });

  testWidgets('05 more', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-more')));
    await tester.pumpAndSettle();
    await snap('screens_05_more');
  });
}
