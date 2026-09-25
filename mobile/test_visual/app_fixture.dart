import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/app_dependencies.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';
import 'package:ttsmart_mobile/features/shell/presentation/screens/app_shell.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';

import 'fixtures_access.dart';
import 'fixtures_org.dart';
import 'fixtures_reports.dart';
import 'fixtures_shell.dart';
import 'harness.dart';

class VisualRepositories {
  VisualRepositories({
    this.orders,
    this.reports,
    this.mixDesigns,
    this.materials,
    this.stations,
    this.weighStations,
  });

  final OrderReportRepository? orders;
  final ReportsRepository? reports;
  final MixDesignRepository? mixDesigns;
  final MaterialReportRepository? materials;
  final StationRepository? stations;
  final WeighStationRepository? weighStations;

  AppFeatureRepositories build(ApiClient api) => AppFeatureRepositories(
    home: VisualHomeRepository(),
    notifications: VisualNotificationRepository(),
    mixDesigns: mixDesigns ?? ApiMixDesignRepository(api),
    materialReports: materials ?? ApiMaterialReportRepository(api),
    orderReports: orders ?? VisualOrderReportRepository(),
    reports: reports ?? VisualReportsRepository(),
    companies: VisualCompanyRepository(),
    stations: stations ?? ApiStationRepository(api),
    weighStations: weighStations ?? ApiWeighStationRepository(api),
  );
}

/// Pumps the whole app shell (bottom navigation included).
Future<AppFeatureRepositories> pumpVisualShell(
  WidgetTester tester, {
  bool admin = true,
  VisualRepositories? repositories,
  Map<String, VisualRoute> routes = const {},
}) async {
  usePhoneFrame(tester);
  final api = visualApiClient(routes);
  final controller = VisualAppController(api, isAdmin: admin);
  addTearDown(controller.dispose);
  final built = (repositories ?? VisualRepositories()).build(api);
  await tester.pumpWidget(visualApp(controller, AppShell(repositories: built)));
  await tester.pumpAndSettle();
  return built;
}

/// Pumps a single screen (no shell) with the signed-in controller.
Future<void> pumpVisualScreen(
  WidgetTester tester,
  Widget screen, {
  bool admin = true,
  Map<String, VisualRoute> routes = const {},
  bool settle = true,
}) async {
  usePhoneFrame(tester);
  final controller = VisualAppController(
    visualApiClient(routes),
    isAdmin: admin,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(visualApp(controller, _PushedScreen(screen)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A spinner never settles: let the route and first frames run.
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

/// Opens [screen] as a pushed route, as the app always does, so its app bar
/// shows the back button.
class _PushedScreen extends StatefulWidget {
  const _PushedScreen(this.screen);

  final Widget screen;

  @override
  State<_PushedScreen> createState() => _PushedScreenState();
}

class _PushedScreenState extends State<_PushedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => widget.screen));
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.white);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  // Lazy lists only build what is on screen (large fonts push it below).
  for (var step = 0; step < 12 && finder.evaluate().isEmpty; step++) {
    final page = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.drag(page.first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  // Centred, so the tap never lands under the fake navigation bar.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
