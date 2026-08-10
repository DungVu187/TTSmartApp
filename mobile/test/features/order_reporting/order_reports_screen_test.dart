import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/models/order_report_models.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/presentation/screens/order_reports_screen.dart';
import 'package:ttsmart_mobile/features/order_reporting/presentation/widgets/order_report_widgets.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _AuthorizedAppController extends AppController {
  _AuthorizedAppController._(ApiClient apiClient, {required this.isAdmin})
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

  final bool isAdmin;

  factory _AuthorizedAppController({bool isAdmin = false}) {
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API thật trong test.'),
      ),
    );
    return _AuthorizedAppController._(apiClient, isAdmin: isAdmin);
  }

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: 'reporter',
      fullName: 'Người xem báo cáo',
      email: null,
      code: null,
      phone: null,
      companyId: 3,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: '10',
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) =>
      functionCode == AccessFunctionCodes.orderReports &&
      permission == AccessPermission.dSach;

  @override
  bool hasRole(String roleCode) => isAdmin && roleCode == 'ADMIN';
}

class _FakeOrderReportRepository implements OrderReportRepository {
  _FakeOrderReportRepository({this.isPartial = false});

  final bool isPartial;
  final requestedCompanyIds = <int?>[];
  final employeeRequests =
      <({int branchId, int? companyId, DateTime fromDate, DateTime toDate})>[];
  final queries = <OrderReportQuery>[];

  @override
  Future<List<OrderReportStation>> getStations({int? companyId}) async {
    requestedCompanyIds.add(companyId);
    return const [
      OrderReportStation(id: 10, companyId: 3, name: 'Trạm 10', typeTram: 1),
    ];
  }

  @override
  Future<List<OrderReportEmployee>> getEmployees({
    required int branchId,
    int? companyId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    employeeRequests.add((
      branchId: branchId,
      companyId: companyId,
      fromDate: fromDate,
      toDate: toDate,
    ));
    return const [OrderReportEmployee(name: 'Nguyễn Văn A')];
  }

  @override
  Future<OrderReportPage> search(OrderReportQuery query) async {
    queries.add(query);
    return OrderReportPage(
      items: [
        OrderReportItem(
          orderId: 101,
          branchId: 10,
          stationName: 'Trạm 10',
          customerName: 'Khách hàng A',
          projectName: 'Dự án A',
          concreteGradeName: 'M250',
          orderedVolume: 24.5,
          producedVolume: 20.333,
          orderedAtUtc: DateTime.utc(2026, 7, 31, 3),
          employeeName: 'Nguyễn Văn A',
        ),
      ],
      pageNumber: 1,
      pageSize: 20,
      totalCount: 1,
      totalPages: 1,
      totalOrderedVolume: 24.5,
      totalProducedVolume: 20.333,
      isPartial: isPartial,
      successfulStationCount: 1,
      unavailableStationCount: isPartial ? 1 : 0,
      unavailableStations: isPartial
          ? const [
              OrderReportUnavailableStation(
                branchId: 20,
                companyId: 3,
                companyName: 'Công ty Alpha',
                stationName: 'Trạm 20',
              ),
            ]
          : const [],
    );
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
  testWidgets('renders authorized order report data on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _AuthorizedAppController();
    final orderRepository = _FakeOrderReportRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: OrderReportsScreen(
            repository: orderRepository,
            companyRepository: _FakeCompanyRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateRange = find.byKey(
      const ValueKey<String>('order-report-date-range'),
    );
    final submitButton = find.byKey(
      const ValueKey<String>('order-report-submit'),
    );
    final resetButton = find.byKey(
      const ValueKey<String>('order-report-reset'),
    );
    final dateRangeSize = tester.getSize(dateRange);
    final submitButtonSize = tester.getSize(submitButton);
    final resetButtonSize = tester.getSize(resetButton);
    final buttonGap =
        tester.getTopLeft(resetButton).dx - tester.getTopRight(submitButton).dx;

    expect(dateRangeSize.height, 38);
    expect(submitButtonSize.height, 38);
    expect(resetButtonSize.height, 38);
    expect(buttonGap, 10);
    expect(submitButtonSize.width, greaterThan(resetButtonSize.width));
    expect(
      submitButtonSize.width + buttonGap + resetButtonSize.width,
      closeTo(dateRangeSize.width, 0.01),
    );
    final stationField = find.byKey(
      const ValueKey<String>('order-report-station-null-1'),
    );
    final stationSearchIcon = find.descendant(
      of: stationField,
      matching: find.byIcon(Icons.search),
    );
    final dateArrow = find.byKey(
      const ValueKey<String>('order-report-date-arrow'),
    );
    expect(stationSearchIcon, findsOneWidget);
    expect(dateArrow, findsNothing);
    final filterDecorators = tester.widgetList<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('order-report-filters')),
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

    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Chọn trạm'), findsOneWidget);
    expect(find.text('Tổng đơn hàng'), findsNothing);
    expect(orderRepository.employeeRequests, isEmpty);
    expect(orderRepository.queries, isEmpty);

    final stationInput = find.descendant(
      of: stationField,
      matching: find.byType(TextFormField),
    );
    await tester.tap(stationInput);
    await tester.enterText(stationInput, '10');
    await tester.pump();
    await tester.tap(find.text('Trạm 10').last);
    await tester.pumpAndSettle();

    expect(orderRepository.employeeRequests.single.branchId, 10);
    expect(orderRepository.employeeRequests.single.companyId, isNull);
    expect(orderRepository.queries, isEmpty);

    final employeeField = find.byKey(
      const ValueKey<String>('order-report-employee-null-1'),
    );
    await tester.ensureVisible(employeeField);
    final employeeInput = find.descendant(
      of: employeeField,
      matching: find.byType(TextFormField),
    );
    await tester.tap(employeeInput);
    await tester.enterText(employeeInput, 'Nguyễn');
    await tester.pump();
    await tester.tap(find.text('Nguyễn Văn A').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();

    expect(find.text('Tổng đơn hàng'), findsOneWidget);
    expect(orderRepository.queries.single.employeeName, 'Nguyễn Văn A');
    final metricCards = find.byType(OrderReportMetricCard);
    expect(metricCards, findsNWidgets(3));
    final firstMetricTop = tester.getTopLeft(metricCards.at(0)).dy;
    expect(tester.getTopLeft(metricCards.at(1)).dy, firstMetricTop);
    expect(tester.getTopLeft(metricCards.at(2)).dy, firstMetricTop);
    await tester.scrollUntilVisible(
      find.text('Đơn #101'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đơn #101'), findsOneWidget);
    expect(find.text('24,5 m³'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters company suggestions by name and selects a company', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _AuthorizedAppController(isAdmin: true);
    final orderRepository = _FakeOrderReportRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: OrderReportsScreen(
            repository: orderRepository,
            companyRepository: _FakeCompanyRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Tất cả công ty'), findsNothing);

    final companyAutocomplete = find.byKey(
      const ValueKey<String>('order-report-company-3-2'),
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

    expect(orderRepository.requestedCompanyIds, contains(4));
    expect(orderRepository.employeeRequests, isEmpty);
    expect(orderRepository.queries, isEmpty);

    await tester.tap(find.byKey(const ValueKey('order-report-reset')));
    await tester.pumpAndSettle();

    expect(orderRepository.requestedCompanyIds.last, isNull);
    expect(find.text('Tất cả công ty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the calendar time range picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _AuthorizedAppController();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: OrderReportsScreen(
            repository: _FakeOrderReportRepository(),
            companyRepository: _FakeCompanyRepository(),
            now: () => DateTime(2026, 8, 4, 8, 59),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('order-report-date-range')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn khoảng thời gian'), findsOneWidget);
    expect(find.text('Chọn giờ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('order-report-date-hour')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('order-report-date-minute')),
      findsOneWidget,
    );
    expect(find.text('Từ ngày'), findsOneWidget);
    expect(find.text('Đến ngày'), findsOneWidget);

    await tester.tap(find.text('Đến ngày'));
    await tester.pump();
    expect(find.text('08'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('order-report-date-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khoảng ngày đơn hàng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows unavailable stations for partial aggregate results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _AuthorizedAppController(isAdmin: true);
    final orderRepository = _FakeOrderReportRepository(isPartial: true);
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: OrderReportsScreen(
            repository: orderRepository,
            companyRepository: _FakeCompanyRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('order-report-partial-warning')),
      findsOneWidget,
    );
    expect(find.text('Kết quả chưa đầy đủ'), findsOneWidget);
    expect(find.textContaining('1 trạm chưa thể truy cập'), findsOneWidget);
    expect(find.textContaining('Trạm 20'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
