import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_request_cancellation.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/controllers/material_report_controller.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/widgets/material_units.dart';

/// 12 vouchers for all/all (the API adds the "Xuất tổng" row on each page),
/// 3 for any other filter.
class _FakeMaterialReportRepository implements MaterialReportRepository {
  final queries = <MaterialReportQuery>[];
  final cancellations = <ApiRequestCancellation?>[];

  /// Holds every report until it completes, like a slow station database.
  Completer<void>? gate;

  @override
  Future<List<MaterialReportStation>> getStations({int? companyId}) async =>
      const [
        MaterialReportStation(
          id: 10,
          companyId: 2,
          name: 'Trạm A',
          companyName: 'Công ty A',
          typeTram: 1,
        ),
      ];

  @override
  Future<MaterialReport> getReport(
    MaterialReportQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    cancellations.add(cancellation);
    final held = gate;
    if (held != null) {
      await Future.any([
        held.future,
        if (cancellation != null) cancellation.whenCancelled,
      ]);
      // What ApiClient does when the request is aborted.
      if (cancellation?.isCancelled ?? false) {
        throw const ApiRequestCancelledException();
      }
    }
    final all =
        query.viewMode == MaterialViewMode.all &&
        query.materialGroup == MaterialGroupFilter.all;
    final total = all ? 12 : 3;
    final first = (query.pageNumber - 1) * 10;
    final rows = [
      for (var index = first; index < total && index < first + 10; index++)
        _voucher('PX-$index'),
      if (all) _summary(),
    ];
    return _report(
      pageNumber: query.pageNumber,
      transactions: rows,
      totalCount: total + (all ? 1 : 0),
    );
  }
}

void main() {
  late ApiClient apiClient;
  late _FakeMaterialReportRepository repository;
  late MaterialReportController controller;

  setUp(() {
    apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Company API must not be called.'),
      ),
    );
    repository = _FakeMaterialReportRepository();
    controller = MaterialReportController(
      repository: repository,
      companyRepository: ApiCompanyRepository(apiClient),
      isAdmin: false,
      now: () => DateTime(2026, 8, 14, 9),
    );
  });

  tearDown(() {
    controller.dispose();
    apiClient.close();
  });

  test('requires explicit station selection before loading report', () async {
    await controller.initialize();

    expect(controller.stations.single.id, 10);
    expect(controller.selectedStationId, isNull);
    await controller.loadReport();

    expect(repository.queries, isEmpty);
    expect(controller.validationMessage, contains('Chọn trạm trộn'));
  });

  test('one report for every material and voucher type feeds the tabs; '
      'quantity/value, chart group and units do not ask again', () async {
    await controller.initialize();
    controller.selectStation(10);
    await controller.loadReport();

    final query = repository.queries.single;
    expect(query.branchId, 10);
    expect(query.companyId, isNull);
    expect(query.materialGroup, MaterialGroupFilter.all);
    expect(query.viewMode, MaterialViewMode.all);
    expect(query.pageNumber, 1);
    // The summary row is shown on its own, not as a voucher.
    expect(controller.summaryExport?.id, 'summary-export');
    expect(controller.vouchers, hasLength(10));
    expect(controller.vouchers.any((item) => item.isSummary), isFalse);
    expect(controller.voucherCount, 12);
    expect(controller.canLoadMoreVouchers, isTrue);

    controller
      ..setValueMode(MaterialValueMode.value)
      ..setChartGroup(MaterialGroupFilter.cement)
      ..setUnit('sand', MaterialUnit.ton);
    expect(repository.queries, hasLength(1));
    expect(controller.unitFor('sand'), MaterialUnit.ton);
    expect(controller.unitFor('stone'), MaterialUnit.kg);
  });

  test('vouchers load more pages and follow their own filters', () async {
    await controller.initialize();
    controller.selectStation(10);
    await controller.loadReport();

    await controller.loadMoreVouchers();
    expect(repository.queries.last.pageNumber, 2);
    expect(controller.vouchers, hasLength(12));
    expect(controller.canLoadMoreVouchers, isFalse);

    await controller.setVoucherFilters(type: MaterialViewMode.exportData);
    expect(repository.queries.last.viewMode, MaterialViewMode.exportData);
    expect(repository.queries.last.pageNumber, 1);
    expect(controller.vouchers, hasLength(3));
    expect(controller.voucherCount, 3);
    // The overview (stock, chart, summary) is untouched.
    expect(controller.summaryExport, isNotNull);

    await controller.setVoucherFilters(
      type: MaterialViewMode.all,
      group: MaterialGroupFilter.sand,
    );
    expect(repository.queries.last.materialGroup, MaterialGroupFilter.sand);

    // Back to all/all: page 1 of the overview, no new request.
    final count = repository.queries.length;
    await controller.setVoucherFilters(group: MaterialGroupFilter.all);
    expect(repository.queries, hasLength(count));
    expect(controller.vouchers, hasLength(10));
  });

  test('a new station, a new date range or leaving the screen cancels the '
      'report still loading, so the API stops its query', () async {
    await controller.initialize();
    repository.gate = Completer<void>();
    controller.selectStation(10);
    final first = controller.loadReport();
    await Future<void>.delayed(Duration.zero);
    controller.selectStation(20);
    await first;
    expect(repository.cancellations.single!.isCancelled, isTrue);
    expect(controller.isLoadingReport, isFalse);
    expect(controller.reportError, isNull);

    final second = controller.loadReport();
    await Future<void>.delayed(Duration.zero);
    controller.setDateRange(DateTime(2026, 8, 1), DateTime(2026, 8, 2));
    await second;
    expect(repository.cancellations.last!.isCancelled, isTrue);

    // Asking again for the same station replaces the older request too.
    final third = controller.loadReport();
    await Future<void>.delayed(Duration.zero);
    final fourth = controller.loadReport();
    await Future<void>.delayed(Duration.zero);
    await third;
    expect(repository.cancellations[2]!.isCancelled, isTrue);
    repository.gate!.complete();
    await fourth;
    expect(repository.cancellations[3]!.isCancelled, isFalse);
    expect(controller.report, isNotNull);

    final screen = MaterialReportController(
      repository: repository..gate = Completer<void>(),
      companyRepository: ApiCompanyRepository(apiClient),
      isAdmin: false,
      now: () => DateTime(2026, 8, 14, 9),
    );
    await screen.initialize();
    screen.selectStation(10);
    final leaving = screen.loadReport();
    await Future<void>.delayed(Duration.zero);
    screen.dispose();
    await leaving;
    expect(repository.cancellations.last!.isCancelled, isTrue);
  });

  test('a new date range clears the report', () async {
    await controller.initialize();
    controller.selectStation(10);
    await controller.loadReport();

    controller.setDateRange(DateTime(2026, 8, 1), DateTime(2026, 8, 2));
    expect(controller.report, isNull);
    expect(controller.vouchers, isEmpty);
  });
}

MaterialTransaction _voucher(String id) => MaterialTransaction(
  rowNumber: 0,
  id: id,
  occurredAt: DateTime.utc(2026, 8, 14, 2),
  periodFrom: null,
  periodTo: null,
  type: 'export',
  content: 'Phiếu xuất $id',
  importQuantityKg: 0,
  exportQuantityKg: 120,
  valueVnd: 400000,
  note: null,
  details: const [],
);

MaterialTransaction _summary() => MaterialTransaction(
  rowNumber: 13,
  id: 'summary-export',
  occurredAt: null,
  periodFrom: DateTime.utc(2026, 7, 31, 17),
  periodTo: DateTime.utc(2026, 8, 14, 2),
  type: 'summary-export',
  content: 'Xuất tổng trong kỳ',
  importQuantityKg: 0,
  exportQuantityKg: 1440,
  valueVnd: 0,
  note: null,
  details: const [],
);

MaterialReport _report({
  required int pageNumber,
  required List<MaterialTransaction> transactions,
  required int totalCount,
}) => MaterialReport(
  stationId: 10,
  stationName: 'Trạm A',
  from: DateTime.utc(2026, 7, 31, 17),
  to: DateTime.utc(2026, 8, 14, 2),
  inventoryAsOf: DateTime.utc(2026, 8, 14, 2),
  groups: const [],
  chartItems: const [],
  transactions: transactions,
  totalCount: totalCount,
  totalPages: (totalCount / 10).ceil(),
  pageNumber: pageNumber,
  pageSize: 10,
  fromRowNumber: 0,
  toRowNumber: 0,
  totals: const MaterialReportTotals(
    importQuantityKg: 0,
    exportQuantityKg: 0,
    inventoryQuantityKg: 0,
    importValueVnd: 0,
    exportValueVnd: 0,
    inventoryValueVnd: 0,
  ),
  warnings: const [],
);
