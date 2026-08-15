import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/screens/material_report_screen.dart';

class _FakeMaterialReportRepository implements MaterialReportRepository {
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
  Future<MaterialReport> getReport(MaterialReportQuery query) async =>
      _report();
}

void main() {
  testWidgets('requires station then shows mobile overview and transactions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Company API must not be called.'),
      ),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MaterialReportScreen(
          repository: _FakeMaterialReportRepository(),
          companyRepository: ApiCompanyRepository(apiClient),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chọn trạm để xem báo cáo'), findsOneWidget);
    expect(find.text('Tổng quan'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trạm A').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('material-view-report')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Tồn hiện tại'), findsOneWidget);
    expect(find.text('Xi măng PCB40'), findsOneWidget);

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('Phiếu xuất kho'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

MaterialReport _report() => MaterialReport(
  stationId: 10,
  stationName: 'Trạm A',
  from: DateTime.utc(2026, 7, 31, 17),
  to: DateTime.utc(2026, 8, 14, 2),
  inventoryAsOf: DateTime.utc(2026, 8, 14, 2),
  groups: const [],
  chartItems: const [
    MaterialChartItem(
      materialCode: 1,
      name: 'Xi măng PCB40',
      groupCode: 'cement',
      importQuantityKg: 100,
      exportQuantityKg: 120,
      inventoryQuantityKg: -20,
      importValueVnd: 400000,
      exportValueVnd: 400000,
      inventoryValueVnd: 0,
    ),
  ],
  transactions: [
    MaterialTransaction(
      rowNumber: 1,
      id: 'PX-1',
      occurredAt: DateTime.utc(2026, 8, 14, 2),
      periodFrom: null,
      periodTo: null,
      type: 'export-manual',
      content: 'Phiếu xuất kho',
      importQuantityKg: 0,
      exportQuantityKg: 120,
      valueVnd: 400000,
      note: null,
      details: const [],
    ),
  ],
  totalCount: 1,
  totalPages: 1,
  pageNumber: 1,
  pageSize: 10,
  fromRowNumber: 1,
  toRowNumber: 1,
  totals: const MaterialReportTotals(
    importQuantityKg: 100,
    exportQuantityKg: 120,
    inventoryQuantityKg: -20,
    importValueVnd: 400000,
    exportValueVnd: 400000,
    inventoryValueVnd: 0,
  ),
  warnings: const [],
);
