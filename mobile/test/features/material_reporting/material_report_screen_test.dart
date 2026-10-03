import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_request_cancellation.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/screens/material_report_screen.dart';

import '../../support/phone_viewport.dart';

class _FakeMaterialReportRepository implements MaterialReportRepository {
  final queries = <MaterialReportQuery>[];

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
    return _report();
  }
}

Future<_FakeMaterialReportRepository> _pump(
  WidgetTester tester, {
  Size? size,
}) async {
  if (size == null) {
    usePhoneViewport(tester);
  } else {
    useViewport(tester, size);
  }
  final apiClient = ApiClient(
    baseUri: Uri.parse('http://localhost'),
    timeout: const Duration(seconds: 1),
    httpClient: MockClient(
      (_) async => throw StateError('Company API must not be called.'),
    ),
  );
  addTearDown(apiClient.close);
  final repository = _FakeMaterialReportRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MaterialReportScreen(
        repository: repository,
        companyRepository: ApiCompanyRepository(apiClient),
        isAdmin: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('stock tab: the only station loads, negative stock is said in '
      'words, value mode and units switch without asking again', (
    tester,
  ) async {
    final repository = await _pump(tester);

    expect(repository.queries.single.branchId, 10);
    expect(repository.queries.single.viewMode, MaterialViewMode.all);
    expect(find.text('Trạm A'), findsOneWidget);
    expect(find.text('Tồn kho'), findsOneWidget);
    expect(find.text('Cả 1 vật liệu đang âm kho'), findsOneWidget);
    expect(find.text('XI MĂNG'), findsOneWidget);
    expect(find.text('Xi măng PCB40'), findsOneWidget);
    expect(find.text('−20 kg'), findsOneWidget);
    expect(find.text('Âm kho'), findsOneWidget);
    expect(find.text('Nhập 100 · Xuất 120 kg'), findsOneWidget);

    await tester.tap(find.text('Giá trị'));
    await tester.pumpAndSettle();
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.text('Tồn −20 kg'), findsOneWidget);
    expect(find.text('Thiếu đơn giá'), findsOneWidget);
    expect(repository.queries, hasLength(1));

    await tester.tap(find.text('Khối lượng'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('material-unit-cement')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('tấn'));
    await tester.pumpAndSettle();
    expect(find.text('−0,02 tấn'), findsOneWidget);
    expect(repository.queries, hasLength(1));

    await tester.tap(find.text('Xi măng PCB40'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng xuất'), findsOneWidget);
    expect(find.text('0,12 tấn'), findsOneWidget);
    // Export of the period comes from the "Xuất tổng" row.
    expect(find.text('Xuất trong kỳ'), findsOneWidget);
    expect(find.text('0,08 tấn'), findsOneWidget);
    expect(find.text('Chưa có hệ số'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart and vouchers tabs', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Biểu đồ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập – xuất – tồn theo vật liệu'), findsOneWidget);
    expect(find.text('−20 kg'), findsOneWidget);
    expect(find.text('120 kg'), findsOneWidget);

    await tester.tap(find.text('Phiếu'));
    await tester.pumpAndSettle();
    expect(find.text('Xuất tổng trong kỳ'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
    // The summary is not listed or counted as a voucher.
    expect(find.text('1 PHIẾU'), findsOneWidget);
    expect(find.text('−120 kg'), findsOneWidget);

    await tester.tap(find.text('Phiếu xuất kho'));
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT VẬT LIỆU'), findsOneWidget);
    expect(find.text('Xuất kho'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout uses the same screen, centred', (tester) async {
    final repository = await _pump(tester, size: const Size(1024, 900));

    expect(repository.queries, hasLength(1));
    expect(find.text('Xi măng PCB40'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('material-view-report')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

MaterialReport _report() => MaterialReport(
  stationId: 10,
  stationName: 'Trạm A',
  from: DateTime.utc(2026, 7, 31, 17),
  to: DateTime.utc(2026, 8, 14, 2),
  inventoryAsOf: DateTime.utc(2026, 8, 14, 2),
  groups: const [
    MaterialGroupSummary(
      code: 'cement',
      name: 'Nhóm Xi',
      materials: [
        MaterialSummaryItem(
          materialCode: 1,
          name: 'Xi măng PCB40',
          groupCode: 'cement',
          importQuantityKg: 100,
          exportQuantityKg: 120,
          inventoryQuantityKg: -20,
          importValueVnd: 400000,
          exportValueVnd: 400000,
          inventoryValueVnd: 0,
          hasMissingImportPrice: true,
          slotNumber: 5,
        ),
      ],
    ),
  ],
  chartItems: const [],
  transactions: [
    MaterialTransaction(
      rowNumber: 1,
      id: 'manual:1',
      occurredAt: DateTime.utc(2026, 8, 14, 2),
      periodFrom: null,
      periodTo: null,
      type: 'export',
      content: 'Phiếu xuất kho',
      importQuantityKg: 0,
      exportQuantityKg: 120,
      valueVnd: 400000,
      note: null,
      details: const [
        MaterialTransactionDetail(
          materialCode: 1,
          name: 'Xi măng PCB40',
          quantityKg: 120,
          valueVnd: 400000,
          unitPriceVndPerKg: 3333,
          conversionVolume: null,
          conversionUnit: null,
          conversionCoefficientKgPerUnit: null,
        ),
      ],
    ),
    MaterialTransaction(
      rowNumber: 2,
      id: 'summary-export',
      occurredAt: null,
      periodFrom: DateTime.utc(2026, 7, 31, 17),
      periodTo: DateTime.utc(2026, 8, 14, 2),
      type: 'summary-export',
      content: 'Xuất tổng trong kỳ',
      importQuantityKg: 0,
      exportQuantityKg: 80,
      valueVnd: 0,
      note: null,
      details: const [
        MaterialTransactionDetail(
          materialCode: 1,
          name: 'Xi măng PCB40',
          quantityKg: 80,
          valueVnd: 0,
          unitPriceVndPerKg: null,
          conversionVolume: null,
          conversionUnit: null,
          conversionCoefficientKgPerUnit: null,
        ),
      ],
    ),
  ],
  totalCount: 2,
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
