import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/controllers/material_report_controller.dart';

class _FakeMaterialReportRepository implements MaterialReportRepository {
  MaterialReportQuery? lastQuery;
  var reportCalls = 0;

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
  Future<MaterialReport> getReport(MaterialReportQuery query) async {
    reportCalls++;
    lastQuery = query;
    return _report(pageNumber: query.pageNumber);
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

    expect(repository.reportCalls, 0);
    expect(controller.validationMessage, contains('Chọn trạm trộn'));
  });

  test('loads selected station and forwards filters and page', () async {
    await controller.initialize();
    controller
      ..selectStation(10)
      ..setMaterialGroup(MaterialGroupFilter.cement)
      ..setViewMode(MaterialViewMode.inventory)
      ..setValueMode(MaterialValueMode.value);

    await controller.loadReport(pageNumber: 2);

    expect(controller.report?.pageNumber, 2);
    expect(repository.lastQuery?.branchId, 10);
    expect(repository.lastQuery?.companyId, isNull);
    expect(repository.lastQuery?.materialGroup, MaterialGroupFilter.cement);
    expect(repository.lastQuery?.viewMode, MaterialViewMode.inventory);
    expect(repository.lastQuery?.valueMode, MaterialValueMode.value);
    expect(repository.lastQuery?.pageNumber, 2);
  });
}

MaterialReport _report({required int pageNumber}) => MaterialReport(
  stationId: 10,
  stationName: 'Trạm A',
  from: DateTime.utc(2026, 7, 31, 17),
  to: DateTime.utc(2026, 8, 14, 2),
  inventoryAsOf: DateTime.utc(2026, 8, 14, 2),
  groups: const [],
  chartItems: const [],
  transactions: const [],
  totalCount: 0,
  totalPages: 2,
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
