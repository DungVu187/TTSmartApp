import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/services/report_export_file_saver.dart';
import 'package:ttsmart_mobile/features/reports/presentation/controllers/reports_controller.dart';

class _FakeReportsRepository implements ReportsRepository {
  final stationCompanyIds = <int?>[];
  final filterQueries = <OrderStatisticsFilterQuery>[];
  final searchQueries = <OrderStatisticsQuery>[];
  Object? nextSearchError;
  Completer<OrderStatisticsPage>? pendingSearch;
  final exportQueries = <OrderStatisticsExportQuery>[];
  Object? nextExportError;
  Completer<OrderStatisticsExportFile>? pendingExport;

  @override
  Future<List<OrderStatisticsStation>> getStations({int? companyId}) async {
    stationCompanyIds.add(companyId);
    return const [
      OrderStatisticsStation(
        id: 10,
        companyId: 3,
        name: 'Trạm 10',
        typeTram: 1,
        companyName: 'Công ty 3',
      ),
    ];
  }

  @override
  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  ) async {
    filterQueries.add(query);
    return const OrderStatisticsFilterOptions(
      vehiclePlates: ['51A-12345'],
      customerNames: ['Khách hàng A'],
      concreteGradeNames: ['M250'],
      employeeNames: ['Nhân viên A'],
    );
  }

  @override
  Future<OrderStatisticsPage> search(OrderStatisticsQuery query) async {
    searchQueries.add(query);
    final pending = pendingSearch;
    if (pending != null) return pending.future;
    final error = nextSearchError;
    nextSearchError = null;
    if (error != null) throw error;
    return _page(query.pageNumber);
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
    items: [_company(3)],
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: 1,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PaginatedCompanyRepository extends _FakeCompanyRepository {
  final requests = <int>[];

  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async {
    requests.add(pageNumber);
    return pageNumber == 1
        ? CompanyPage(
            items: [_company(3)],
            pageNumber: 1,
            pageSize: pageSize,
            totalCount: 2,
            totalPages: 2,
          )
        : CompanyPage(
            items: [_company(18084)],
            pageNumber: 2,
            pageSize: pageSize,
            totalCount: 2,
            totalPages: 2,
          );
  }
}

void main() {
  test('loads all company pages for admin statistics scope', () async {
    final companyRepository = _PaginatedCompanyRepository();
    final controller = ReportsController(
      repository: _FakeReportsRepository(),
      companyRepository: companyRepository,
      now: () => DateTime(2026, 8, 3, 9),
    );

    await controller.initialize(isAdmin: true, initialCompanyId: null);

    expect(companyRepository.requests, [1, 2]);
    expect(controller.companies.map((company) => company.id), [3, 18084]);
    controller.dispose();
  });

  test(
    'initializes filters without searching and updates default end time',
    () async {
      var now = DateTime(2026, 8, 3, 8);
      final repository = _FakeReportsRepository();
      final controller = ReportsController(
        repository: repository,
        companyRepository: _FakeCompanyRepository(),
        now: () => now,
      );

      await controller.initialize(isAdmin: false, initialCompanyId: 3);

      expect(controller.viewMode, ReportViewMode.detail);
      expect(controller.fromDate, DateTime(2026, 8, 3));
      expect(controller.toDate, DateTime(2026, 8, 3, 8));
      expect(repository.stationCompanyIds, [3]);
      expect(repository.searchQueries, isEmpty);

      await controller.selectStation(10);
      expect(repository.filterQueries, hasLength(1));
      expect(repository.filterQueries.single.from, DateTime(2026, 8, 3));
      expect(repository.filterQueries.single.to, DateTime(2026, 8, 3, 8));
      expect(repository.searchQueries, isEmpty);

      now = DateTime(2026, 8, 3, 9, 15, 30);
      await controller.search();

      expect(repository.searchQueries.single.to, now);
      expect(repository.searchQueries.single.pageNumber, 1);
      expect(controller.result?.items.single.rowNumber, 1);
      controller.dispose();
    },
  );

  test('manual time reloads options and clears dependent filters', () async {
    var now = DateTime(2026, 8, 3, 8);
    final repository = _FakeReportsRepository();
    final controller = ReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      now: () => now,
    );
    await controller.initialize(isAdmin: true, initialCompanyId: null);
    expect(repository.stationCompanyIds, isEmpty);

    await controller.selectCompany(3);
    await controller.selectStation(10);
    controller.setVehiclePlate('51A-12345');
    controller.setCustomerName('Khách hàng A');
    controller.setConcreteGradeName('M250');
    controller.setEmployeeName('Nhân viên A');

    final manualFrom = DateTime(2026, 8, 2, 6, 30);
    final manualTo = DateTime(2026, 8, 2, 17, 45);
    await controller.setTimeRange(manualFrom, manualTo);

    expect(controller.usesDefaultTimeRange, isFalse);
    expect(controller.selectedVehiclePlate, isNull);
    expect(controller.selectedCustomerName, isNull);
    expect(controller.selectedConcreteGradeName, isNull);
    expect(controller.selectedEmployeeName, isNull);
    expect(repository.filterQueries, hasLength(2));
    expect(repository.filterQueries.last.from, manualFrom);
    expect(repository.filterQueries.last.to, manualTo);
    expect(repository.searchQueries, isEmpty);

    await controller.setTimeRange(manualFrom, manualTo);
    expect(repository.filterQueries, hasLength(2));

    controller.setVehiclePlate('51A-12345');
    controller.setViewMode(ReportViewMode.total);
    expect(controller.selectedCompanyId, 3);
    expect(controller.selectedStationId, 10);
    expect(controller.selectedVehiclePlate, '51A-12345');

    now = DateTime(2026, 8, 3, 20);
    await controller.search();
    expect(repository.searchQueries.single.from, manualFrom);
    expect(repository.searchQueries.single.to, manualTo);
    expect(repository.searchQueries.single.viewMode, ReportViewMode.total);
    controller.dispose();
  });

  test(
    'validates scope, keeps old result on error and pages immediately',
    () async {
      final repository = _FakeReportsRepository();
      final controller = ReportsController(
        repository: repository,
        companyRepository: _FakeCompanyRepository(),
        now: () => DateTime(2026, 8, 3, 9),
      );
      await controller.initialize(isAdmin: true, initialCompanyId: null);

      await controller.search();
      expect(controller.feedbackMessage, 'Chưa chọn công ty.');
      expect(repository.searchQueries, isEmpty);

      await controller.selectCompany(3);
      await controller.search();
      expect(controller.feedbackMessage, 'Chưa chọn trạm.');
      expect(repository.searchQueries, isEmpty);

      await controller.selectStation(10);
      await controller.search();
      final firstResult = controller.result;
      expect(firstResult?.pageNumber, 1);

      repository.nextSearchError = const ApiException(
        type: ApiFailureType.server,
        message: 'Trạm tạm thời không truy cập được.',
      );
      await controller.search();
      expect(controller.result, same(firstResult));
      expect(controller.feedbackMessage, 'Trạm tạm thời không truy cập được.');

      await controller.goToNextPage();
      expect(repository.searchQueries.last.pageNumber, 2);
      expect(controller.result?.pageNumber, 2);
      expect(controller.result?.items.single.rowNumber, 11);

      await controller.goToFirstPage();
      expect(repository.searchQueries.last.pageNumber, 1);
      controller.dispose();
    },
  );

  test('ignores an old search result after a filter changes', () async {
    final repository = _FakeReportsRepository();
    final controller = ReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      now: () => DateTime(2026, 8, 3, 9),
    );
    await controller.initialize(isAdmin: false, initialCompanyId: 3);
    await controller.selectStation(10);

    final pending = Completer<OrderStatisticsPage>();
    repository.pendingSearch = pending;
    final searchFuture = controller.search();
    await Future<void>.delayed(Duration.zero);

    controller.setVehiclePlate('51A-12345');
    pending.complete(_page(1));
    repository.pendingSearch = null;
    await searchFuture;

    expect(controller.result, isNull);
    expect(controller.isSearching, isFalse);
    controller.dispose();
  });

  test('exports once, saves the file and reports forbidden access', () async {
    final repository = _FakeReportsRepository();
    final fileSaver = _FakeReportExportFileSaver();
    final controller = ReportsController(
      repository: repository,
      companyRepository: _FakeCompanyRepository(),
      exportFileSaver: fileSaver,
      now: () => DateTime(2026, 8, 3, 9),
    );
    await controller.initialize(isAdmin: false, initialCompanyId: 3);
    await controller.selectStation(10);
    controller.setVehiclePlate('51A-12345');

    final pending = Completer<OrderStatisticsExportFile>();
    repository.pendingExport = pending;
    final exportFuture = controller.exportExcel();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isExporting, isTrue);
    await controller.exportExcel();
    expect(repository.exportQueries, hasLength(1));

    pending.complete(
      OrderStatisticsExportFile(bytes: Uint8List.fromList(<int>[1, 2, 3])),
    );
    repository.pendingExport = null;
    await exportFuture;

    expect(controller.isExporting, isFalse);
    expect(repository.exportQueries.single.companyId, 3);
    expect(repository.exportQueries.single.branchId, 10);
    expect(repository.exportQueries.single.vehiclePlate, '51A-12345');
    expect(fileSaver.savedFiles, hasLength(1));
    expect(controller.feedbackMessage, contains('thong-ke-don-hang.xlsx'));

    repository.nextExportError = const ApiException(
      type: ApiFailureType.forbidden,
      message: 'Forbidden',
      statusCode: 403,
    );
    await controller.exportExcel();

    expect(
      controller.feedbackMessage,
      'Bạn không có quyền xuất Excel thống kê đơn hàng.',
    );
    expect(fileSaver.savedFiles, hasLength(1));
    controller.dispose();
  });
}

OrderStatisticsPage _page(int pageNumber) => OrderStatisticsPage(
  items: [
    OrderStatisticsItem(
      rowNumber: pageNumber == 1 ? 1 : 11,
      stationId: 10,
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
