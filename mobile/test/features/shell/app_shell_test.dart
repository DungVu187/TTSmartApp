import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/app_dependencies.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/models/data_scope.dart';
import 'package:ttsmart_mobile/core/models/time_range_preset.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/home/data/models/dashboard_models.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/shell/presentation/screens/app_shell.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';

import '../../support/empty_reports_repository.dart';

const _surfaceSize = Size(411, 914);
const _selectedBackground = Color(0xFFDBEAFE);
const _selectedColor = Color(0xFF2563EB);
const _unselectedColor = Color(0xFF64748B);

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _AuthorizedAppController extends AppController {
  _AuthorizedAppController(ApiClient apiClient, {this.isAdmin = true})
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

  final bool isAdmin;

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: 'superadmin',
      fullName: 'Super Admin',
      email: null,
      code: null,
      phone: null,
      companyId: 1,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: null,
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) {
    if (functionCode == AccessFunctionCodes.materialReports) {
      return permission == AccessPermission.view;
    }
    return permission == AccessPermission.dSach &&
        const <String>{
          AccessFunctionCodes.orderReports,
          AccessFunctionCodes.orderStatistics,
          AccessFunctionCodes.mixDesigns,
          AccessFunctionCodes.functions,
          AccessFunctionCodes.roles,
          AccessFunctionCodes.users,
          AccessFunctionCodes.companies,
          AccessFunctionCodes.branches,
          AccessFunctionCodes.weighStations,
        }.contains(functionCode);
  }

  @override
  bool hasRole(String roleCode) => isAdmin && roleCode == 'ADMIN';
}

class _ShellHomeRepository implements HomeRepository {
  DashboardScope? lastScope;
  TimeRangePreset? lastTimeRange;
  var dashboardCallCount = 0;

  static const scopes = <DashboardScope>[
    DashboardScope(
      keyName: 'company-1',
      label: 'Công ty A',
      type: DataScopeType.company,
      companyId: 1,
    ),
    DashboardScope(
      keyName: 'station-10',
      label: 'Trạm A',
      type: DataScopeType.station,
      companyId: 1,
      branchId: 10,
      description: 'Công ty A',
    ),
  ];

  @override
  Future<List<DashboardScope>> getAvailableScopes() async => scopes;

  @override
  Future<DashboardSnapshot> getDashboard({
    required DashboardScope? scope,
    required TimeRangePreset timeRange,
  }) async {
    dashboardCallCount++;
    lastScope = scope;
    lastTimeRange = timeRange;
    return DashboardSnapshot(
      scope: scope,
      timeRange: timeRange,
      updatedAt: DateTime.utc(2026, 8, 12),
      totalMixedVolume: 0,
      metrics: const <DashboardMetric>[
        DashboardMetric(
          type: DashboardMetricType.orders,
          label: 'Đơn hàng',
          value: '0',
          caption: 'Hôm nay',
        ),
        DashboardMetric(
          type: DashboardMetricType.concreteGrades,
          label: 'Mác bê tông',
          value: '0',
          caption: 'Hôm nay',
        ),
        DashboardMetric(
          type: DashboardMetricType.mixerTrucks,
          label: 'Xe trộn',
          value: '0',
          caption: 'Hôm nay',
        ),
        DashboardMetric(
          type: DashboardMetricType.salesWithOrders,
          label: 'Kinh doanh có đơn',
          value: '0',
          caption: 'Hôm nay',
        ),
      ],
      chartLabels: const <String>[],
      chartValues: const <double>[],
      stations: const <StationOverview>[],
    );
  }
}

void main() {
  testWidgets('hides company filter on dashboard for non-admin accounts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API thật trong test.'),
      ),
    );
    final appController = _AuthorizedAppController(apiClient, isAdmin: false);
    addTearDown(appController.dispose);
    final homeRepository = _ShellHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: AppShell(
            repositories: AppFeatureRepositories(
              home: homeRepository,
              mixDesigns: ApiMixDesignRepository(apiClient),
              materialReports: ApiMaterialReportRepository(apiClient),
              orderReports: ApiOrderReportRepository(apiClient),
              reports: const EmptyReportsRepository(),
              companies: ApiCompanyRepository(apiClient),
              stations: ApiStationRepository(apiClient),
              weighStations: ApiWeighStationRepository(apiClient),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dashboard-company-filter')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-station-filter-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-time-range-today')),
      findsOneWidget,
    );
    expect(homeRepository.dashboardCallCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows five navigation items and opens shell panels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API thật trong test.'),
      ),
    );
    final appController = _AuthorizedAppController(apiClient);
    addTearDown(appController.dispose);

    final homeRepository = _ShellHomeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: AppShell(
            repositories: AppFeatureRepositories(
              home: homeRepository,
              mixDesigns: ApiMixDesignRepository(apiClient),
              materialReports: ApiMaterialReportRepository(apiClient),
              orderReports: ApiOrderReportRepository(apiClient),
              reports: const EmptyReportsRepository(),
              companies: ApiCompanyRepository(apiClient),
              stations: ApiStationRepository(apiClient),
              weighStations: ApiWeighStationRepository(apiClient),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('shell-bottom-navigation')),
      findsOneWidget,
    );
    for (final tab in <String>[
      'home',
      'orders',
      'statistics',
      'system',
      'more',
    ]) {
      expect(find.byKey(ValueKey<String>('shell-nav-$tab')), findsOneWidget);
    }
    _expectNavigationColors(tester, selectedKey: 'home', unselectedKey: 'more');

    // Home scope chips (Figma "02 Home") open picker sheets.
    expect(
      find.byKey(const ValueKey<String>('dashboard-filters')),
      findsOneWidget,
    );
    expect(homeRepository.dashboardCallCount, 1);
    expect(homeRepository.lastScope, isNull);
    expect(homeRepository.lastTimeRange, TimeRangePreset.today);
    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-company-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Công ty A').last);
    await tester.pumpAndSettle();
    final stationChip = find.byKey(
      const ValueKey<String>('dashboard-station-filter-1'),
    );
    await tester.ensureVisible(stationChip);
    await tester.pumpAndSettle();
    await tester.tap(stationChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trạm A').last);
    await tester.pumpAndSettle();

    expect(homeRepository.lastScope?.branchId, 10);
    expect(homeRepository.lastScope?.companyId, 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dashboard-station-filter-1')),
        matching: find.text('Trạm A'),
      ),
      findsOneWidget,
    );
    for (final metric in <String>[
      'orders',
      'concreteGrades',
      'mixerTrucks',
      'salesWithOrders',
    ]) {
      expect(
        find.byKey(ValueKey<String>('dashboard-metric-$metric')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('dashboard-production-chart')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // "Hệ thống" is a full tab page (Figma S01).
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-system')));
    await tester.pumpAndSettle();
    expect(find.text('Hệ thống'), findsWidgets);
    for (final module in <String>['users', 'roles', 'functions']) {
      expect(find.byKey(ValueKey<String>('system-$module')), findsOneWidget);
    }
    _expectNavigationColors(
      tester,
      selectedKey: 'system',
      unselectedKey: 'home',
    );
    expect(tester.takeException(), isNull);

    // "Xem thêm" is a sheet over the current tab (Figma 05 More).
    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('more-sheet')), findsOneWidget);
    expect(find.text('VẬN HÀNH'), findsOneWidget);
    expect(find.text('TỔ CHỨC & HỆ THỐNG'), findsOneWidget);
    for (final label in <String>[
      'Quản lý cấp phối',
      'Quản lý cân ô tô',
      'Quản lý vật liệu',
      'Quản lý trạm',
      'Quản lý công ty',
    ]) {
      expect(find.byKey(ValueKey<String>('more-tile-$label')), findsOneWidget);
    }
    expect(find.text('Quản lý xe'), findsNothing);
    expect(find.text('Quản lý camera'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('more-tile-Quản lý cấp phối')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('more-sheet')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('mix-design-filters')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectNavigationColors(
  WidgetTester tester, {
  required String selectedKey,
  required String unselectedKey,
}) {
  final selectedItem = find.byKey(ValueKey<String>('shell-nav-$selectedKey'));
  final selectedContainerFinder = find.descendant(
    of: selectedItem,
    matching: find.byType(AnimatedContainer),
  );
  expect(selectedContainerFinder, findsOneWidget);
  // Figma: 52×30 pill behind the icon only.
  expect(tester.getSize(selectedContainerFinder), const Size(52, 30));
  final selectedContainer = tester.widget<AnimatedContainer>(
    selectedContainerFinder,
  );
  expect(
    (selectedContainer.decoration! as BoxDecoration).color,
    _selectedBackground,
  );
  _expectNavigationForeground(tester, selectedItem, _selectedColor);

  final unselectedItem = find.byKey(
    ValueKey<String>('shell-nav-$unselectedKey'),
  );
  _expectNavigationForeground(tester, unselectedItem, _unselectedColor);
}

void _expectNavigationForeground(
  WidgetTester tester,
  Finder item,
  Color expectedColor,
) {
  final iconFinder = find.descendant(of: item, matching: find.byType(Icon));
  final textFinder = find.descendant(of: item, matching: find.byType(Text));

  expect(iconFinder, findsOneWidget);
  expect(textFinder, findsOneWidget);
  expect(tester.widget<Icon>(iconFinder).color, expectedColor);
  expect(tester.widget<Text>(textFinder).style?.color, expectedColor);
}
