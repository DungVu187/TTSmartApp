import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/app_dependencies.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/notifications/data/repositories/notifications_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';
import 'package:ttsmart_mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:ttsmart_mobile/features/shell/presentation/screens/app_shell.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';

const _surfaceSize = Size(411, 914);
const _selectedBackground = Color(0xFFEEF2FF);
const _selectedColor = Color(0xFF2563EB);
const _unselectedColor = Color(0xFF6B7280);

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _AuthorizedAppController extends AppController {
  _AuthorizedAppController(ApiClient apiClient)
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

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
  bool hasRole(String roleCode) => roleCode == 'ADMIN';
}

void main() {
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: AppShell(
            repositories: AppFeatureRepositories(
              home: const MockHomeRepository(),
              mixDesigns: ApiMixDesignRepository(apiClient),
              orderReports: ApiOrderReportRepository(apiClient),
              reports: const MockReportsRepository(),
              notifications: const MockNotificationsRepository(),
              settings: MemorySettingsRepository(),
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

    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-system')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('shell-panel-system')),
      findsOneWidget,
    );
    expect(find.text('Chức năng'), findsOneWidget);
    expect(find.text('Phân quyền'), findsOneWidget);
    expect(find.text('Người dùng'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('module-panel-grid-scroll')),
      findsOneWidget,
    );
    _expectPanelDesign(tester);
    _expectFourColumnGrid(tester);
    _expectModuleTileDesign(tester, index: 0, label: 'Chức năng');
    expect(find.text('(Trống)'), findsNothing);
    _expectNavigationColors(
      tester,
      selectedKey: 'system',
      unselectedKey: 'home',
    );
    final systemPanelSize = tester.getSize(
      find.byKey(const ValueKey<String>('shell-panel-surface')),
    );
    expect(
      find.byKey(const ValueKey<String>('shell-bottom-navigation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('shell-panel-close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('shell-panel-system')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('shell-nav-more')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('shell-panel-more')),
      findsOneWidget,
    );
    expect(find.text('Quản lý cấp phối'), findsOneWidget);
    expect(find.text('Quản lý cân ô tô'), findsOneWidget);
    expect(find.text('Quản lý trạm'), findsOneWidget);
    expect(find.text('Quản lý công ty'), findsOneWidget);
    expect(find.text('Quản lý xe'), findsNothing);
    expect(find.text('Quản lý camera'), findsNothing);
    expect(find.text('Quản lý vật liệu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('module-panel-grid-scroll')),
      findsOneWidget,
    );
    _expectPanelDesign(tester);
    _expectFourColumnGrid(tester);
    _expectModuleTileDesign(tester, index: 0, label: 'Quản lý cấp phối');
    _expectNavigationColors(
      tester,
      selectedKey: 'more',
      unselectedKey: 'system',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('shell-panel-surface'))),
      systemPanelSize,
    );
    expect(
      find.byKey(const ValueKey<String>('shell-bottom-navigation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('module-panel-tile-0')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mix-design-filters')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectPanelDesign(WidgetTester tester) {
  final panelSurface = find.byKey(
    const ValueKey<String>('shell-panel-surface'),
  );
  final bottomNavigation = find.byKey(
    const ValueKey<String>('shell-bottom-navigation'),
  );
  final panelRect = tester.getRect(panelSurface);
  final bottomNavigationTop = tester.getRect(bottomNavigation).top;
  final expectedPanelHeight = (bottomNavigationTop * 0.40)
      .clamp(340.0, 520.0)
      .toDouble();

  expect(panelRect.left, closeTo(0, 0.01));
  expect(panelRect.right, closeTo(_surfaceSize.width, 0.01));
  expect(panelRect.height, closeTo(expectedPanelHeight, 0.01));
  expect(
    panelRect.top,
    closeTo(bottomNavigationTop - expectedPanelHeight, 0.01),
  );
  expect(panelRect.bottom, closeTo(bottomNavigationTop, 0.01));

  final panelMaterial = tester.widget<Material>(panelSurface);
  final panelShape = panelMaterial.shape! as RoundedRectangleBorder;
  final panelRadius = panelShape.borderRadius.resolve(TextDirection.ltr);
  expect(panelMaterial.color, Colors.white);
  expect(panelRadius.topLeft, const Radius.circular(16));
  expect(panelRadius.topRight, const Radius.circular(16));

  final closeButton = find.byKey(const ValueKey<String>('shell-panel-close'));
  expect(tester.getSize(closeButton), const Size(32, 32));
  final closeIconFinder = find.descendant(
    of: closeButton,
    matching: find.byIcon(Icons.close),
  );
  expect(closeIconFinder, findsOneWidget);
  final closeIcon = tester.widget<Icon>(closeIconFinder);
  expect(closeIcon.size, 16);
  final closeIconButton = tester.widget<IconButton>(closeButton);
  expect(
    closeIconButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
    _unselectedColor,
  );
}

void _expectFourColumnGrid(WidgetTester tester) {
  final gridFinder = find.byKey(
    const ValueKey<String>('module-panel-grid-scroll'),
  );
  final grid = tester.widget<GridView>(gridFinder);
  final padding = grid.padding!.resolve(TextDirection.ltr);
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

  expect(padding.left, 16);
  expect(padding.right, 16);
  expect(delegate.crossAxisCount, 4);
  expect(delegate.crossAxisSpacing, 16);
  expect(delegate.mainAxisExtent, 76);
}

void _expectModuleTileDesign(
  WidgetTester tester, {
  required int index,
  required String label,
}) {
  final tile = find.byKey(ValueKey<String>('module-panel-tile-$index'));
  final iconBackground = find.byKey(
    ValueKey<String>('module-panel-icon-background-$index'),
  );

  expect(tile, findsOneWidget);
  expect(iconBackground, findsOneWidget);
  expect(tester.getSize(iconBackground), const Size(36, 36));

  final iconFinder = find.descendant(
    of: iconBackground,
    matching: find.byType(Icon),
  );
  expect(iconFinder, findsOneWidget);
  expect(tester.widget<Icon>(iconFinder).size, 18);

  final labelFinder = find.descendant(of: tile, matching: find.text(label));
  expect(labelFinder, findsOneWidget);
  final labelText = tester.widget<Text>(labelFinder);
  expect(labelText.style?.fontSize, 13);
  expect(labelText.style?.fontWeight, FontWeight.w500);
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
