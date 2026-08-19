import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';
import 'package:ttsmart_mobile/features/reports/presentation/widgets/statistics_tables.dart';

void main() {
  testWidgets('renders three material groups and maps values by columnKey', (
    tester,
  ) async {
    await _setSurface(tester);
    final columns = <OrderStatisticsMaterialColumn>[
      _column(1, 'Cát 3', 'cat-a'),
      _column(2, 'Cát 2', 'cat-b'),
      _column(3, 'Cát 1', 'cat-c'),
    ];
    final page = _page(
      items: [
        _item(
          layoutKey: 'layout-cat',
          salesEmployeeName: 'Kinh doanh A',
          employeeName: 'Người vận hành B',
          materials: [
            _material(3, 'Cát 1', 'cat-a', actual: 301),
            _material(1, 'Cát 3', 'cat-b', actual: 202),
            _material(2, 'Cát 2', 'cat-c', actual: 103),
          ],
        ),
      ],
      layouts: [
        OrderStatisticsMaterialLayout(
          layoutKey: 'layout-cat',
          columns: columns,
        ),
      ],
    );

    await _pump(tester, StatisticsResultsTable(page: page));

    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('statistics-sticky-index-column'),
            ),
          )
          .width,
      56,
    );
    final materialLabels = <String>{
      for (final column in columns) ...{
        column.designLabel,
        column.tLabel,
        column.actualLabel,
        column.varianceLabel,
      },
    };
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && materialLabels.contains(widget.data),
      ),
      findsNWidgets(12),
    );
    expect(
      tester.getCenter(find.text('TT.Cát 3')).dx,
      closeTo(tester.getCenter(find.text('301')).dx, 0.01),
    );
    expect(
      tester.getCenter(find.text('TT.Cát 2')).dx,
      closeTo(tester.getCenter(find.text('202')).dx, 0.01),
    );
    expect(
      tester.getCenter(find.text('TT.Cát 1')).dx,
      closeTo(tester.getCenter(find.text('103')).dx, 0.01),
    );
    expect(
      tester.getCenter(find.text('NV KINH DOANH')).dx,
      closeTo(tester.getCenter(find.text('Kinh doanh A')).dx, 0.01),
    );
    expect(
      tester.getCenter(find.text('TÊN NHÂN VIÊN')).dx,
      closeTo(tester.getCenter(find.text('Người vận hành B')).dx, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders all columns when a layout has more than fourteen slots',
    (tester) async {
      await _setSurface(tester);
      final columns = [
        for (var index = 1; index <= 15; index++)
          _column(index, 'Vật liệu $index', 'material-$index'),
      ];
      final page = _page(
        items: [_item(layoutKey: 'layout-15')],
        layouts: [
          OrderStatisticsMaterialLayout(
            layoutKey: 'layout-15',
            columns: columns,
          ),
        ],
      );

      await _pump(tester, StatisticsResultsTable(page: page));

      for (final column in columns) {
        expect(find.text(column.designLabel), findsOneWidget);
        expect(find.text(column.tLabel), findsOneWidget);
        expect(find.text(column.actualLabel), findsOneWidget);
        expect(find.text(column.varianceLabel), findsOneWidget);
      }
      expect(find.text('TT.Vật liệu 15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows all ten data rows inside the table frame', (tester) async {
    await _setSurface(tester);
    final page = _page(
      items: [
        for (var rowNumber = 1; rowNumber <= 10; rowNumber++)
          _item(layoutKey: 'layout-ten-rows', rowNumber: rowNumber),
      ],
      layouts: [
        OrderStatisticsMaterialLayout(
          layoutKey: 'layout-ten-rows',
          columns: [_column(1, 'Cát 1', 'cat-1')],
        ),
      ],
    );

    await _pump(tester, StatisticsResultsTable(page: page));

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('statistics-layout-table-frame')),
          )
          .height,
      569,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('statistics-sticky-index-column'),
            ),
          )
          .height,
      520,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('statistics-sticky-index-column'),
        ),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resets table scroll when a new search result arrives', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final layout = OrderStatisticsMaterialLayout(
      layoutKey: 'layout-scroll',
      columns: [_column(1, 'Cát 1', 'cat-1')],
    );
    final firstPage = _page(
      items: [_item(layoutKey: layout.layoutKey)],
      layouts: [layout],
    );

    await _pump(tester, StatisticsResultsTable(page: firstPage));
    final bodyFinder = find.byKey(
      const ValueKey<String>('statistics-table-horizontal-scroll'),
    );
    final headerFinder = find.byKey(
      const ValueKey<String>('statistics-sticky-header-scroll'),
    );
    await tester.drag(bodyFinder, const Offset(-120, 0));
    await tester.pumpAndSettle();

    double offsetOf(Finder finder) =>
        tester.widget<SingleChildScrollView>(finder).controller!.offset;

    expect(offsetOf(bodyFinder), greaterThan(0));
    expect(offsetOf(headerFinder), greaterThan(0));

    await _pump(tester, StatisticsResultsTable(page: firstPage));
    expect(offsetOf(bodyFinder), greaterThan(0));

    final nextPage = _page(
      items: [_item(layoutKey: layout.layoutKey, rowNumber: 11)],
      layouts: [layout],
    );
    await _pump(tester, StatisticsResultsTable(page: nextPage));

    expect(offsetOf(bodyFinder), 0);
    expect(offsetOf(headerFinder), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separates items from two layout keys into two tables', (
    tester,
  ) async {
    await _setSurface(tester);
    final page = _page(
      items: [
        _item(layoutKey: 'layout-a', rowNumber: 1),
        _item(layoutKey: 'layout-b', rowNumber: 2),
      ],
      layouts: [
        OrderStatisticsMaterialLayout(
          layoutKey: 'layout-a',
          columns: [_column(1, 'Cát lịch sử', 'cat-history')],
        ),
        OrderStatisticsMaterialLayout(
          layoutKey: 'layout-b',
          columns: [_column(1, 'Đá hiện tại', 'stone-current')],
        ),
      ],
    );

    await _pump(tester, StatisticsResultsTable(page: page));

    expect(
      find.byKey(const ValueKey<String>('statistics-layout-group-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-layout-group-1')),
      findsOneWidget,
    );
    expect(find.text('Bố cục vật liệu 1'), findsOneWidget);
    expect(find.text('Bố cục vật liệu 2'), findsOneWidget);
    expect(find.text('TT.Cát lịch sử'), findsOneWidget);
    expect(find.text('TT.Đá hiện tại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses zero for a missing historical material slot', (
    tester,
  ) async {
    await _setSurface(tester);
    final page = _page(
      items: [_item(layoutKey: 'layout-missing')],
      layouts: [
        OrderStatisticsMaterialLayout(
          layoutKey: 'layout-missing',
          columns: [_column(1, 'Cát thiếu', 'missing-column')],
        ),
      ],
    );

    await _pump(tester, StatisticsResultsTable(page: page));

    expect(find.text('ĐM.Cát thiếu'), findsOneWidget);
    expect(find.text('T.Cát thiếu'), findsOneWidget);
    expect(find.text('TT.Cát thiếu'), findsOneWidget);
    expect(find.text('SS.Cát thiếu'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'formats detail values by business category without exposing station code',
    (tester) async {
      await _setSurface(tester);
      final columns = <OrderStatisticsMaterialColumn>[
        _column(1, 'Cát', 'cat', categoryCode: 'CAT'),
        _column(2, 'Đá', 'da', categoryCode: 'DA'),
        _column(3, 'Xi măng', 'ximang', categoryCode: 'XIMANG'),
        _column(4, 'Nước', 'nuoc', categoryCode: 'NUOC'),
        _column(5, 'Phụ gia', 'phugia', categoryCode: 'PHUGIA'),
        _column(6, 'Tro bay', 'khac', categoryCode: 'KHAC'),
      ];
      final page = _page(
        items: [
          _item(
            layoutKey: 'layout-format',
            stationCode: 'SECRET_STATION_CODE',
            stationName: 'Trạm Lam Sơn',
            employeeName: null,
            requestedVolume: 10.5,
            mixedVolume: 12.345,
            materials: [
              _material(1, 'Cát', 'cat', actual: 10.4, categoryCode: 'CAT'),
              _material(2, 'Đá', 'da', actual: 12.6, categoryCode: 'DA'),
              _material(
                3,
                'Xi măng',
                'ximang',
                actual: 10.56,
                categoryCode: 'XIMANG',
              ),
              _material(4, 'Nước', 'nuoc', actual: 11.04, categoryCode: 'NUOC'),
              _material(
                5,
                'Phụ gia',
                'phugia',
                actual: 10.567,
                categoryCode: 'PHUGIA',
              ),
              _material(
                6,
                'Tro bay',
                'khac',
                actual: 20.567,
                categoryCode: 'KHAC',
              ),
            ],
          ),
        ],
        layouts: [
          OrderStatisticsMaterialLayout(
            layoutKey: 'layout-format',
            columns: columns,
          ),
        ],
      );

      await _pump(tester, StatisticsResultsTable(page: page));

      expect(find.text('Trạm Lam Sơn'), findsOneWidget);
      expect(find.textContaining('SECRET_STATION_CODE'), findsNothing);
      expect(find.text('10.5'), findsWidgets);
      expect(find.text('10.500'), findsNothing);
      expect(find.text('12.345'), findsOneWidget);
      expect(find.text('10'), findsWidgets);
      expect(find.text('13'), findsWidgets);
      expect(find.text('10.6'), findsWidgets);
      expect(find.text('11'), findsWidgets);
      expect(find.text('10.57'), findsWidgets);
      expect(find.text('20.57'), findsWidgets);
      expect(find.text('Tài xế A'), findsOneWidget);
      final employeeHeaderX = tester.getTopLeft(find.text('TÊN NHÂN VIÊN')).dx;
      final hasEmptyEmployeeCell = find
          .text('—')
          .evaluate()
          .map(
            (element) =>
                find.byElementPredicate((candidate) => candidate == element),
          )
          .any(
            (finder) =>
                (tester.getTopLeft(finder).dx - employeeHeaderX).abs() < 0.01,
          );
      expect(hasEmptyEmployeeCell, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders actual summary rows, units and totals like web', (
    tester,
  ) async {
    await _setSurface(tester);
    final page = _page(
      totalMaterialQuantity: 147825.078,
      totalConcreteVolume: 62.567,
      summaryRows: [
        for (var position = 1; position <= 3; position++) _summaryRow(position),
      ],
    );

    await _pump(tester, StatisticsMaterialSummaryTable(page: page));

    for (var position = 1; position <= 3; position++) {
      expect(
        find.byKey(ValueKey<String>('statistics-summary-row-$position')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('statistics-summary-row-4')),
      findsNothing,
    );
    expect(find.text('VẬT LIỆU'), findsOneWidget);
    expect(find.text('ĐM'), findsNothing);
    expect(find.text('T'), findsNothing);
    expect(find.text('Thực tế'), findsNothing);
    expect(find.text('SS'), findsNothing);
    final missingStoneCell = find.byKey(
      const ValueKey<String>('statistics-summary-1-DA-actual'),
    );
    expect(
      find.descendant(of: missingStoneCell, matching: find.text('0')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('statistics-summary-unit-CAT')),
        matching: find.text('KG'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('statistics-summary-unit-NUOC')),
        matching: find.text('LÍT'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-summary-unit-row-label')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey<String>('statistics-summary-total-material'),
            ),
          )
          .data,
      '147,825.08 kg',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey<String>('statistics-summary-total-concrete'),
            ),
          )
          .data,
      '62.567 m³',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders all twelve material summary positions', (tester) async {
    await _setSurface(tester);
    final page = _page(
      summaryRows: [
        for (var position = 1; position <= 12; position++)
          _summaryRow(position),
      ],
    );

    await _pump(tester, StatisticsMaterialSummaryTable(page: page));

    expect(
      find.byKey(const ValueKey<String>('statistics-summary-row-12')),
      findsOneWidget,
    );
    final actualCell = find.byKey(
      const ValueKey<String>('statistics-summary-12-CAT-actual'),
    );
    expect(
      find.descendant(of: actualCell, matching: find.text('1,012')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('formats summary materials with category-specific precision', (
    tester,
  ) async {
    await _setSurface(tester);
    final cells = <OrderStatisticsMaterialSummaryCell>[
      _summaryCell('CAT', 10.4),
      _summaryCell('DA', 12.6),
      _summaryCell('XIMANG', 10.56),
      _summaryCell('NUOC', 11.04),
      _summaryCell('PHUGIA', 10.567),
      _summaryCell('KHAC', 20.567),
    ];
    final page = _page(
      summaryRows: [
        OrderStatisticsMaterialSummaryRow(rowNumber: 1, cells: cells),
      ],
    );

    await _pump(tester, StatisticsMaterialSummaryTable(page: page));

    for (final expectation in <String, String>{
      'CAT': '10',
      'DA': '13',
      'XIMANG': '10.6',
      'NUOC': '11',
      'PHUGIA': '10.57',
      'KHAC': '20.57',
    }.entries) {
      final cell = find.byKey(
        ValueKey<String>('statistics-summary-1-${expectation.key}-actual'),
      );
      expect(
        find.descendant(of: cell, matching: find.text(expectation.value)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

OrderStatisticsMaterialColumn _column(
  int slotNumber,
  String materialName,
  String columnKey, {
  String categoryCode = 'CAT',
}) => OrderStatisticsMaterialColumn(
  materialSlotId: slotNumber,
  slotNumber: slotNumber,
  materialName: materialName,
  category: materialName,
  categoryCode: categoryCode,
  typePosition: slotNumber,
  columnKey: columnKey,
  designLabel: 'ĐM.$materialName',
  tLabel: 'T.$materialName',
  actualLabel: 'TT.$materialName',
  varianceLabel: 'SS.$materialName',
  unit: 'kg',
);

OrderStatisticsMaterial _material(
  int slotNumber,
  String materialName,
  String columnKey, {
  double actual = 0,
  String categoryCode = 'CAT',
}) => OrderStatisticsMaterial(
  materialSlotId: slotNumber,
  slotNumber: slotNumber,
  materialName: materialName,
  category: materialName,
  categoryCode: categoryCode,
  typePosition: slotNumber,
  columnKey: columnKey,
  designQuantity: 0,
  tQuantity: 0,
  actualQuantity: actual,
  variance: 0,
);

OrderStatisticsItem _item({
  required String layoutKey,
  int rowNumber = 1,
  String? salesEmployeeName,
  String? employeeName,
  String? stationCode,
  String? stationName = 'Trạm 10',
  double requestedVolume = 10,
  double mixedVolume = 9,
  List<OrderStatisticsMaterial> materials = const [],
}) => OrderStatisticsItem(
  rowNumber: rowNumber,
  stationId: 10,
  stationCode: stationCode,
  stationName: stationName,
  mixingDate: DateTime(2026, 8, 3),
  startedAt: DateTime.utc(2026, 8, 3, 1),
  finishedAt: DateTime.utc(2026, 8, 3, 1, 10),
  customerName: 'Khách hàng A',
  projectName: 'Dự án A',
  workItemName: 'Hạng mục A',
  locationName: 'Địa điểm A',
  vehiclePlate: '51A-12345',
  driverName: 'Tài xế A',
  concreteGradeName: 'M300',
  slump: '12±2',
  salesEmployeeName: salesEmployeeName,
  employeeName: employeeName,
  layoutKey: layoutKey,
  requestedVolume: requestedVolume,
  mixedVolume: mixedVolume,
  materials: materials,
);

OrderStatisticsMaterialSummaryRow _summaryRow(int position) =>
    OrderStatisticsMaterialSummaryRow(
      rowNumber: position,
      cells: [
        OrderStatisticsMaterialSummaryCell(
          categoryCode: 'CAT',
          typePosition: position,
          materialSlotId: position,
          slotNumber: position,
          materialName: 'Cát $position',
          category: 'Cát',
          columnKey: 'cat-$position',
          actualQuantity: (1000 + position).toDouble(),
        ),
      ],
    );

OrderStatisticsMaterialSummaryCell _summaryCell(
  String categoryCode,
  double actualQuantity,
) => OrderStatisticsMaterialSummaryCell(
  categoryCode: categoryCode,
  typePosition: 1,
  materialSlotId: 1,
  slotNumber: 1,
  materialName: categoryCode,
  category: categoryCode,
  columnKey: categoryCode.toLowerCase(),
  actualQuantity: actualQuantity,
);

OrderStatisticsPage _page({
  List<OrderStatisticsItem> items = const [],
  List<OrderStatisticsMaterialLayout> layouts = const [],
  List<OrderStatisticsMaterialSummaryRow> summaryRows = const [],
  double totalMaterialQuantity = 0,
  double totalConcreteVolume = 0,
}) => OrderStatisticsPage(
  items: items,
  totalCount: items.length,
  totalPages: items.isEmpty ? 0 : 1,
  pageNumber: 1,
  pageSize: 10,
  fromRowNumber: items.isEmpty ? 0 : 1,
  toRowNumber: items.length,
  totalMaterialQuantity: totalMaterialQuantity,
  totalConcreteVolume: totalConcreteVolume,
  layouts: layouts,
  materialSummaryRows: summaryRows,
);
