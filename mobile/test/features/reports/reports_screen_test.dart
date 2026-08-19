import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/services/report_export_file_saver.dart';
import 'package:ttsmart_mobile/features/reports/presentation/screens/reports_screen.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _AuthorizedAppController extends AppController {
  _AuthorizedAppController(
    ApiClient apiClient, {
    this.isAdmin = false,
    this.canExport = false,
  }) : super(
         apiClient: apiClient,
         authRepository: AuthRepository(apiClient),
         accessManagementRepository: AccessManagementRepository(apiClient),
         tokenStorage: _MemoryTokenStorage(),
       );

  final bool isAdmin;
  final bool canExport;

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: 'statistics-user',
      fullName: 'Người xem thống kê',
      email: null,
      code: null,
      phone: null,
      companyId: 3,
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
  bool hasRole(String roleCode) => isAdmin && roleCode == 'ADMIN';

  @override
  bool hasPermission(String functionCode, AccessPermission permission) =>
      functionCode == AccessFunctionCodes.orderStatistics &&
      (permission == AccessPermission.dSach ||
          (permission == AccessPermission.exportData && canExport));
}

class _FakeReportsRepository implements ReportsRepository {
  final searchQueries = <OrderStatisticsQuery>[];
  final requestedCompanyIds = <int?>[];
  Completer<List<OrderStatisticsStation>>? pendingStations;
  Completer<OrderStatisticsPage>? pendingSearch;
  Completer<OrderStatisticsExportFile>? pendingExport;
  final exportQueries = <OrderStatisticsExportQuery>[];
  Object? nextSearchError;
  Object? nextExportError;
  Object? nextStationError;

  @override
  Future<List<OrderStatisticsStation>> getStations({int? companyId}) async {
    requestedCompanyIds.add(companyId);
    final pending = pendingStations;
    if (pending != null) return pending.future;
    final error = nextStationError;
    nextStationError = null;
    if (error != null) throw error;
    return const [
      OrderStatisticsStation(
        id: 10,
        companyId: 3,
        name: 'Trạm 10',
        typeTram: 1,
        companyName: 'Công ty 3',
        code: 'TRAM_10',
      ),
    ];
  }

  @override
  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  ) async => const OrderStatisticsFilterOptions(
    vehiclePlates: ['51A-12345', '30B-67890'],
    customerNames: ['Khách hàng A', 'Khách hàng B'],
    concreteGradeNames: ['M250', 'M300'],
    employeeNames: ['Nhân viên A', 'Nhân viên B'],
  );

  @override
  Future<OrderStatisticsPage> search(OrderStatisticsQuery query) {
    searchQueries.add(query);
    final pending = pendingSearch;
    if (pending != null) return pending.future;
    final error = nextSearchError;
    nextSearchError = null;
    if (error != null) return Future<OrderStatisticsPage>.error(error);
    return Future.value(_page(query.pageNumber));
  }

  @override
  Future<OrderStatisticsExportFile> export(
    OrderStatisticsExportQuery query,
  ) async {
    exportQueries.add(query);
    final pending = pendingExport;
    if (pending != null) return pending.future;
    final error = nextExportError;
    nextExportError = null;
    if (error != null) throw error;
    return OrderStatisticsExportFile(bytes: Uint8List.fromList(<int>[1, 2, 3]));
  }
}

class _FakeReportExportFileSaver implements ReportExportFileSaver {
  final savedFiles = <OrderStatisticsExportFile>[];

  @override
  Future<String> save(OrderStatisticsExportFile file) async {
    savedFiles.add(file);
    return 'C:\\Downloads\\${file.fileName}';
  }
}

class _FakeCompanyRepository implements CompanyRepository {
  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async => CompanyPage(
    items: [_company(3, 'Công ty Alpha'), _company(4, 'Công ty Beta')],
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: 2,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CompanyResponse _company(int id, String name) => CompanyResponse(
  id: id,
  code: 'CT$id',
  name: name,
  email: null,
  phone: null,
  address: null,
  fax: null,
  representative: null,
  contactName: null,
  contactEmail: null,
  contactPhone: null,
  createdAtUtc: null,
  updatedAtUtc: null,
  userId: null,
  status: CompanyDataStatus.active,
  isActive: true,
  countUser: 1,
  plan: CompanyPlan.paid,
  isLocked: false,
  note: null,
  logo: null,
  expiredDate: null,
);

void main() {
  testWidgets('shows initial loading and retries a station API error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _appController();
    final repository = _FakeReportsRepository();
    final pendingStations = Completer<List<OrderStatisticsStation>>();
    repository.pendingStations = pendingStations;
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppScope(
            controller: appController,
            child: ReportsScreen(
              repository: repository,
              companyRepository: _FakeCompanyRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pendingStations.completeError(
      const ApiException(
        type: ApiFailureType.network,
        message: 'Không thể kết nối để tải danh sách trạm.',
      ),
    );
    repository.pendingStations = null;
    await tester.pumpAndSettle();

    expect(find.text('Không thể kết nối để tải danh sách trạm.'), findsWidgets);
    final retry = find.widgetWithText(TextButton, 'Thử lại');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Thử lại'), findsNothing);
    expect(repository.requestedCompanyIds, [3, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not auto search and uses the calendar time picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _appController();
    final repository = _FakeReportsRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppScope(
            controller: appController,
            child: ReportsScreen(
              repository: repository,
              companyRepository: _FakeCompanyRepository(),
              now: () => DateTime(2026, 8, 3, 8, 37),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.searchQueries, isEmpty);
    expect(find.text('Chi tiết'), findsOneWidget);
    expect(find.text('Mẻ hoàn thành'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('statistics-summary-title')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-export')),
      findsNothing,
    );
    expect(find.text('03/08/2026 00:00 - 03/08/2026 08:37'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('statistics-date-range')))
          .height,
      38,
    );
    final dateFieldSize = tester.getSize(
      find.byKey(const ValueKey<String>('statistics-date-range')),
    );
    final searchRect = tester.getRect(
      find.byKey(const ValueKey<String>('statistics-search')),
    );
    final resetRect = tester.getRect(
      find.byKey(const ValueKey<String>('statistics-reset')),
    );
    expect(searchRect.height, 38);
    expect(resetRect.height, 38);
    expect(resetRect.left - searchRect.right, 10);
    expect(searchRect.width, greaterThan(resetRect.width));
    expect(
      searchRect.width + 10 + resetRect.width,
      closeTo(dateFieldSize.width, 0.01),
    );
    final stationField = find.byKey(
      const ValueKey<String>('statistics-station-null-1'),
    );
    final stationSearchIcon = find.descendant(
      of: stationField,
      matching: find.byIcon(Icons.search),
    );
    final dateArrow = find.byKey(
      const ValueKey<String>('statistics-date-arrow'),
    );
    expect(stationSearchIcon, findsOneWidget);
    expect(dateArrow, findsNothing);
    final filterDecorators = tester.widgetList<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('statistics-filters')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(filterDecorators, isNotEmpty);
    for (final decorator in filterDecorators) {
      final enabledBorder =
          decorator.decoration.enabledBorder! as OutlineInputBorder;
      expect(enabledBorder.borderSide.color, const Color(0xFFCBD5E1));
      expect(enabledBorder.borderSide.width, 1.25);
    }
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('statistics-vehicle--0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không có dữ liệu'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('statistics-date-range')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('statistics-date-range')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chọn khoảng thời gian'), findsOneWidget);
    expect(find.text('Chọn giờ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('statistics-date-hour')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-date-minute')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('statistics-date-close')),
    );
    await tester.pumpAndSettle();
    expect(repository.searchQueries, isEmpty);
  });

  testWidgets('filters company suggestions and selects a company', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _appController(isAdmin: true);
    final repository = _FakeReportsRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppScope(
            controller: appController,
            child: ReportsScreen(
              repository: repository,
              companyRepository: _FakeCompanyRepository(),
              now: () => DateTime(2026, 8, 3, 8, 37),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedCompanyIds, isEmpty);
    expect(find.text('Chưa chọn công ty.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('statistics-search')));
    await tester.pumpAndSettle();

    expect(find.text('Chưa chọn công ty.'), findsOneWidget);
    expect(repository.searchQueries, isEmpty);

    final companyAutocomplete = find.byKey(
      const ValueKey<String>('statistics-company-null-2'),
    );
    final companyInput = find.descendant(
      of: companyAutocomplete,
      matching: find.byType(TextFormField),
    );
    await tester.tap(companyInput);
    await tester.enterText(companyInput, 'Beta');
    await tester.pump();

    expect(find.text('Công ty Beta'), findsOneWidget);
    await tester.tap(find.text('Công ty Beta'));
    await tester.pumpAndSettle();

    expect(repository.requestedCompanyIds.last, 4);
    expect(repository.searchQueries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows retry for API errors and switches to total table', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _appController();
    final repository = _FakeReportsRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppScope(
            controller: appController,
            child: ReportsScreen(
              repository: repository,
              companyRepository: _FakeCompanyRepository(),
              now: () => DateTime(2026, 8, 3, 8, 37),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stationField = find.byKey(
      const ValueKey<String>('statistics-station-null-1'),
    );
    final stationInput = find.descendant(
      of: stationField,
      matching: find.byType(TextFormField),
    );
    await tester.tap(stationInput);
    await tester.enterText(stationInput, '10');
    await tester.pump();
    expect(find.text('Trạm 10'), findsWidgets);
    expect(find.textContaining('TRAM_10'), findsNothing);
    await tester.tap(find.text('Trạm 10').last);
    await tester.pumpAndSettle();

    final searchButton = find.byKey(
      const ValueKey<String>('statistics-search'),
    );
    await tester.scrollUntilVisible(
      searchButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    repository.nextSearchError = const ApiException(
      type: ApiFailureType.notFound,
      message: 'Không tìm thấy dữ liệu thống kê.',
      statusCode: 404,
    );
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy dữ liệu thống kê.'), findsWidgets);
    final retryButton = find.text('Thử lại');
    expect(retryButton, findsOneWidget);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('statistics-results-table')),
      findsOneWidget,
    );
    expect(repository.searchQueries.last.branchId, 10);
    expect(find.textContaining('TRAM_10'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('statistics-pagination')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-summary-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-material-summary-table')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('statistics-view-mode')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('statistics-view-mode')),
        matching: find.text('Tổng hợp'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      searchButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('statistics-material-summary-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-results-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-pagination')),
      findsOneWidget,
    );
    expect(repository.searchQueries.last.viewMode, ReportViewMode.total);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locks search, renders empty table and pages immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _appController();
    final repository = _FakeReportsRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppScope(
            controller: appController,
            child: ReportsScreen(
              repository: repository,
              companyRepository: _FakeCompanyRepository(),
              now: () => DateTime(2026, 8, 3, 8, 37),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stationField = find.byKey(
      const ValueKey<String>('statistics-station-null-1'),
    );
    final stationInput = find.descendant(
      of: stationField,
      matching: find.byType(TextFormField),
    );
    await tester.tap(stationInput);
    await tester.enterText(stationInput, '10');
    await tester.pump();
    await tester.tap(find.text('Trạm 10').last);
    await tester.pumpAndSettle();

    for (final filterKey in <String>[
      'statistics-vehicle--2',
      'statistics-customer--2',
      'statistics-grade--2',
      'statistics-employee--2',
    ]) {
      final filterField = find.byKey(ValueKey<String>(filterKey));
      expect(
        find.descendant(of: filterField, matching: find.byType(TextFormField)),
        findsOneWidget,
      );
    }

    final searchButton = find.byKey(
      const ValueKey<String>('statistics-search'),
    );
    await tester.scrollUntilVisible(
      searchButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    repository.pendingSearch = Completer<OrderStatisticsPage>();
    await tester.tap(searchButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(searchButton).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repository.pendingSearch!.complete(
      OrderStatisticsPage.empty(viewMode: ReportViewMode.detail),
    );
    repository.pendingSearch = null;
    await tester.pumpAndSettle();

    expect(find.text('Không có dữ liệu'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('statistics-sticky-index-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-sticky-index-column')),
      findsOneWidget,
    );
    expect(repository.searchQueries.single.pageNumber, 1);

    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    final nextButton = find.byKey(
      const ValueKey<String>('statistics-page-next'),
    );
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(repository.searchQueries.last.pageNumber, 2);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('statistics-sticky-index-column'),
        ),
        matching: find.text('11'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exports with permission and shows a Vietnamese 403 message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _appController(canExport: true);
    final repository = _FakeReportsRepository();
    final fileSaver = _FakeReportExportFileSaver();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppScope(
            controller: appController,
            child: ReportsScreen(
              repository: repository,
              companyRepository: _FakeCompanyRepository(),
              exportFileSaver: fileSaver,
              now: () => DateTime(2026, 8, 3, 8, 37),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stationField = find.byKey(
      const ValueKey<String>('statistics-station-null-1'),
    );
    final stationInput = find.descendant(
      of: stationField,
      matching: find.byType(TextFormField),
    );
    await tester.tap(stationInput);
    await tester.enterText(stationInput, '10');
    await tester.pump();
    await tester.tap(find.text('Trạm 10').last);
    await tester.pumpAndSettle();

    final exportButton = find.byKey(
      const ValueKey<String>('statistics-export'),
    );
    await tester.scrollUntilVisible(
      exportButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final pending = Completer<OrderStatisticsExportFile>();
    repository.pendingExport = pending;
    await tester.tap(exportButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(exportButton).onPressed, isNull);
    expect(repository.exportQueries, hasLength(1));

    pending.complete(
      OrderStatisticsExportFile(bytes: Uint8List.fromList(<int>[1, 2, 3])),
    );
    repository.pendingExport = null;
    await tester.pumpAndSettle();

    expect(fileSaver.savedFiles, hasLength(1));
    expect(find.textContaining('Đã lưu file Excel'), findsOneWidget);

    repository.nextExportError = const ApiException(
      type: ApiFailureType.forbidden,
      message: 'Forbidden',
      statusCode: 403,
    );
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn không có quyền xuất Excel thống kê đơn hàng.'),
      findsOneWidget,
    );
    expect(fileSaver.savedFiles, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

_AuthorizedAppController _appController({
  bool isAdmin = false,
  bool canExport = false,
}) {
  final apiClient = ApiClient(
    baseUri: Uri.parse('http://localhost:5052'),
    timeout: const Duration(seconds: 1),
    httpClient: MockClient(
      (_) async => throw StateError('Không gọi API thật trong widget test.'),
    ),
  );
  return _AuthorizedAppController(
    apiClient,
    isAdmin: isAdmin,
    canExport: canExport,
  );
}

OrderStatisticsPage _page(int pageNumber) => OrderStatisticsPage(
  items: [
    OrderStatisticsItem(
      rowNumber: pageNumber == 1 ? 1 : 11,
      stationId: 10,
      stationCode: 'TRAM_10',
      stationName: 'Trạm 10',
      mixingDate: DateTime(2026, 8, 3),
      startedAt: DateTime.utc(2026, 8, 3, 1),
      finishedAt: DateTime.utc(2026, 8, 3, 1, 10),
      customerName: 'Khách hàng A',
      projectName: null,
      workItemName: null,
      locationName: null,
      vehiclePlate: '51A-12345',
      driverName: null,
      concreteGradeName: 'M250',
      slump: null,
      salesEmployeeName: null,
      employeeName: 'Nhân viên A',
      requestedVolume: 10,
      mixedVolume: 9,
      materials: const <OrderStatisticsMaterial>[],
    ),
  ],
  totalCount: 11,
  totalPages: 2,
  pageNumber: pageNumber,
  pageSize: 10,
  fromRowNumber: pageNumber == 1 ? 1 : 11,
  toRowNumber: pageNumber == 1 ? 1 : 11,
  totalMaterialQuantity: 0,
  totalConcreteVolume: 9,
);
