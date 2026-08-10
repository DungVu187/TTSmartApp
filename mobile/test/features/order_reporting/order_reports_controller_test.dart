import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/models/order_report_models.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/presentation/controllers/order_reports_controller.dart';

class _FakeOrderReportRepository implements OrderReportRepository {
  _FakeOrderReportRepository({this.isPartial = false});

  final bool isPartial;
  final stationCompanyIds = <int?>[];
  final employeeRequests =
      <({int branchId, int? companyId, DateTime fromDate, DateTime toDate})>[];
  final queries = <OrderReportQuery>[];

  @override
  Future<List<OrderReportStation>> getStations({int? companyId}) async {
    stationCompanyIds.add(companyId);
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
    final orderId = query.pageNumber == 1 ? 101 : 102;
    return OrderReportPage(
      items: [
        OrderReportItem(
          orderId: orderId,
          branchId: 10,
          stationName: 'Trạm 10',
          customerName: 'Khách hàng',
          projectName: 'Dự án',
          concreteGradeName: 'M250',
          orderedVolume: 10,
          producedVolume: 8,
          orderedAtUtc: DateTime.utc(2026, 7, 31, 3),
          employeeName: 'Nguyễn Văn A',
        ),
      ],
      pageNumber: query.pageNumber,
      pageSize: query.pageSize,
      totalCount: 2,
      totalPages: 2,
      totalOrderedVolume: 20,
      totalProducedVolume: 16,
      isPartial: isPartial,
      successfulStationCount: 1,
      unavailableStationCount: isPartial ? 1 : 0,
      unavailableStations: isPartial
          ? const [
              OrderReportUnavailableStation(
                branchId: 20,
                companyId: 3,
                companyName: 'Công ty 3',
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
    items: [_company(3), _company(4)],
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: 2,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CompanyResponse _company(int id) => CompanyResponse(
  id: id,
  code: 'CT$id',
  name: 'Công ty $id',
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
  test('only loads employees and report after explicit actions', () async {
    final repository = _FakeOrderReportRepository();
    final controller = OrderReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      isAdmin: false,
      now: () => DateTime(2026, 7, 31, 9),
    );

    await controller.initialize();

    expect(repository.stationCompanyIds, [null]);
    expect(controller.selectedStationId, isNull);
    expect(repository.employeeRequests, isEmpty);
    expect(repository.queries, isEmpty);
    expect(controller.items, isEmpty);
    expect(controller.hasLoadedReport, isFalse);

    await controller.selectStation(10);
    expect(repository.employeeRequests.single.branchId, 10);
    expect(repository.employeeRequests.single.companyId, isNull);
    expect(repository.employeeRequests.single.fromDate, DateTime(2026, 7, 31));
    expect(repository.employeeRequests.single.toDate, DateTime(2026, 7, 31, 9));
    expect(repository.queries, isEmpty);
    expect(controller.items, isEmpty);

    await controller.loadReport();
    expect(repository.queries.single.branchId, 10);
    expect(controller.items.single.orderId, 101);
    expect(controller.hasLoadedReport, isTrue);

    await controller.loadMore();
    expect(controller.items.map((item) => item.orderId), [101, 102]);
    controller.dispose();
  });

  test('company selection only reloads stations', () async {
    final repository = _FakeOrderReportRepository();
    final controller = OrderReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      isAdmin: true,
      now: () => DateTime(2026, 7, 31, 9),
    );

    await controller.initialize();
    expect(controller.selectedCompanyId, isNull);
    expect(repository.stationCompanyIds, [null]);
    expect(controller.selectedStationId, isNull);
    expect(repository.employeeRequests, isEmpty);
    expect(repository.queries, isEmpty);

    await controller.selectCompany(3);
    expect(repository.stationCompanyIds, [null, 3]);
    expect(controller.selectedStationId, isNull);
    expect(repository.employeeRequests, isEmpty);
    expect(repository.queries, isEmpty);

    await controller.selectStation(10);
    expect(repository.employeeRequests.last.branchId, 10);
    expect(repository.employeeRequests.last.companyId, 3);
    expect(repository.queries, isEmpty);

    await controller.loadReport();
    expect(repository.queries.last.branchId, 10);
    expect(repository.queries.last.companyId, 3);
    controller.dispose();
  });

  test('applies and clears partial result metadata', () async {
    final repository = _FakeOrderReportRepository(isPartial: true);
    final controller = OrderReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      isAdmin: true,
      now: () => DateTime(2026, 7, 31, 9),
    );

    await controller.initialize();
    await controller.loadReport();

    expect(controller.isPartial, isTrue);
    expect(controller.successfulStationCount, 1);
    expect(controller.unavailableStationCount, 1);
    expect(controller.unavailableStations.single.branchId, 20);

    controller.setEmployeeName('Nguyễn Văn A');

    expect(controller.isPartial, isFalse);
    expect(controller.successfulStationCount, 0);
    expect(controller.unavailableStationCount, 0);
    expect(controller.unavailableStations, isEmpty);
    controller.dispose();
  });

  test('reset restores admin filters and clears previous results', () async {
    final repository = _FakeOrderReportRepository();
    final controller = OrderReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      isAdmin: true,
      now: () => DateTime(2026, 8, 1, 9),
    );

    await controller.initialize();
    await controller.selectCompany(3);
    await controller.selectStation(10);
    await controller.setDateRange(
      DateTimeRangeValue(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
    );
    controller.setEmployeeName('Nguyễn Văn A');
    await controller.loadReport();

    await controller.resetFilters();

    expect(controller.selectedCompanyId, isNull);
    expect(controller.selectedStationId, isNull);
    expect(controller.selectedEmployeeName, isNull);
    expect(controller.fromDate, DateTime(2026, 8, 1));
    expect(controller.toDate, DateTime(2026, 8, 1, 9));
    expect(controller.items, isEmpty);
    expect(controller.hasLoadedReport, isFalse);
    expect(repository.stationCompanyIds.last, isNull);
    controller.dispose();
  });

  test('changing filters clears previous report results', () async {
    final repository = _FakeOrderReportRepository();
    final controller = OrderReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      isAdmin: true,
      now: () => DateTime(2026, 7, 31, 9),
    );

    await controller.initialize();
    await controller.selectStation(10);
    await controller.loadReport();
    expect(controller.items, isNotEmpty);

    await controller.setDateRange(
      DateTimeRangeValue(
        start: DateTime(2026, 7, 31),
        end: DateTime(2026, 7, 31, 9),
      ),
    );
    expect(repository.employeeRequests, hasLength(1));
    expect(controller.items, isNotEmpty);

    await controller.setDateRange(
      DateTimeRangeValue(
        start: DateTime(2026, 7, 30),
        end: DateTime(2026, 7, 31),
      ),
    );
    expect(controller.items, isEmpty);
    expect(controller.hasLoadedReport, isFalse);
    expect(repository.employeeRequests, hasLength(2));
    expect(repository.employeeRequests.last.fromDate, DateTime(2026, 7, 30));
    expect(repository.employeeRequests.last.toDate, DateTime(2026, 7, 31));

    await controller.loadReport();
    controller.setEmployeeName('Nguyễn Văn A');
    expect(controller.items, isEmpty);
    expect(controller.hasLoadedReport, isFalse);

    await controller.loadReport();
    await controller.selectStation(null);
    expect(controller.items, isEmpty);
    expect(controller.hasLoadedReport, isFalse);

    await controller.selectStation(10);
    await controller.loadReport();
    await controller.selectCompany(3);
    expect(controller.items, isEmpty);
    expect(controller.hasLoadedReport, isFalse);
    controller.dispose();
  });
}
