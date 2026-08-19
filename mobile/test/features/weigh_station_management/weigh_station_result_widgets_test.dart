import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_result_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/presentation/widgets/weigh_station_result_widgets.dart';

void main() {
  testWidgets('chi tiết hiển thị đúng giá trị quy đổi backend trả', (
    tester,
  ) async {
    await _pump(
      tester,
      WeighStationDetailTable(
        page: WeighStationPage(
          items: const [
            WeighStationItem(
              stt: 1,
              id: 'ticket-1',
              ticketNumber: 15,
              ticketCode: 'PC-015',
              goodsWeightKg: 1000,
              convertedQuantity: 1,
              convertedUnit: 'tấn',
              materialValueVnd: 4200000,
              hasConversionConfiguration: true,
            ),
          ],
          pageNumber: 1,
          pageSize: 10,
          totalCount: 1,
          totalPages: 1,
          canViewMaterialValue: false,
        ),
      ),
    );

    expect(find.text('1.000'), findsOneWidget);
    expect(find.text('1 tấn'), findsOneWidget);
    expect(find.text('Giá trị (VNĐ)'), findsNothing);
    expect(
      tester.getSize(find.byType(DataTable)).height,
      lessThanOrEqualTo(90),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary hiển thị nhiều đơn vị thành các dòng riêng', (
    tester,
  ) async {
    const summary = WeighStationSummary(
      items: [
        WeighStationSummaryItem(
          stt: 1,
          goodsName: 'Đá 1x2',
          goodsWeightKg: 4132780,
          convertedQuantities: [
            WeighStationConvertedQuantity(quantity: 4070.75, unit: 'tấn'),
            WeighStationConvertedQuantity(quantity: 62030, unit: 'L'),
            WeighStationConvertedQuantity(quantity: 1.35, unit: 'm³'),
            WeighStationConvertedQuantity(quantity: 12.3456, unit: 'bao'),
          ],
        ),
      ],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 1,
      totalPages: 1,
      totalGoodsWeightKg: 4132780,
      totalConvertedQuantities: [
        WeighStationConvertedQuantity(quantity: 4070.75, unit: 'tấn'),
        WeighStationConvertedQuantity(quantity: 62030, unit: 'L'),
        WeighStationConvertedQuantity(quantity: 1.35, unit: 'm³'),
        WeighStationConvertedQuantity(quantity: 12.3456, unit: 'bao'),
      ],
      groups: [],
      canViewMaterialValue: false,
    );

    await _pump(
      tester,
      Column(
        children: [
          WeighStationSummaryOverview(summary: summary),
          WeighStationSummaryTable(summary: summary),
        ],
      ),
    );

    expect(find.text('4.132.780 kg'), findsOneWidget);
    expect(find.text('4.070,75 tấn'), findsNWidgets(2));
    expect(find.text('62.030 L'), findsNWidgets(2));
    expect(find.text('1,35 m³'), findsNWidgets(2));
    expect(find.text('12,346 bao'), findsNWidgets(2));
    final tonTop = tester.getTopLeft(find.text('4.070,75 tấn').first).dy;
    final literTop = tester.getTopLeft(find.text('62.030 L').first).dy;
    expect(tonTop, lessThan(literTop));
    expect(
      tester.getSize(find.byType(DataTable)).height,
      lessThanOrEqualTo(132),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chi tiết không tự tính lại từ goodsWeightKg', (tester) async {
    await _pump(
      tester,
      WeighStationDetailTable(
        page: WeighStationPage(
          items: const [
            WeighStationItem(
              stt: 1,
              id: 'backend-value',
              ticketNumber: 16,
              goodsWeightKg: 1000,
              convertedQuantity: 28.09,
              convertedUnit: 'tấn',
              hasConversionConfiguration: true,
            ),
          ],
          pageNumber: 1,
          pageSize: 10,
          totalCount: 1,
          totalPages: 1,
          canViewMaterialValue: false,
        ),
      ),
    );

    expect(find.text('28,09 tấn'), findsOneWidget);
    expect(find.text('1 tấn'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chi tiết ưu tiên conversionMessage và dùng màu cảnh báo', (
    tester,
  ) async {
    await _pump(
      tester,
      WeighStationDetailTable(
        page: WeighStationPage(
          items: const [
            WeighStationItem(
              stt: 1,
              id: 'no-config',
              ticketNumber: 1,
              convertedUnit: 'tấn',
              conversionMessage: 'Chưa xác định',
              hasConversionConfiguration: false,
            ),
            WeighStationItem(
              stt: 2,
              id: 'no-quantity',
              ticketNumber: 2,
              convertedUnit: 'tấn',
              hasConversionConfiguration: true,
            ),
            WeighStationItem(
              stt: 3,
              id: 'no-unit',
              ticketNumber: 3,
              convertedUnit: '  ',
              hasConversionConfiguration: true,
            ),
          ],
          pageNumber: 1,
          pageSize: 10,
          totalCount: 3,
          totalPages: 1,
          canViewMaterialValue: false,
        ),
      ),
    );

    expect(find.text('Chưa xác định'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(2));
    final warning = tester.widget<Text>(find.text('Chưa xác định'));
    expect(warning.style?.color, AppColors.warning);
    expect(tester.takeException(), isNull);
  });

  testWidgets('convertedQuantities rỗng hiển thị gạch ngang', (tester) async {
    const summary = WeighStationSummary(
      items: [
        WeighStationSummaryItem(
          stt: 1,
          goodsName: 'Không quy đổi',
          goodsWeightKg: 500,
          convertedQuantities: [],
        ),
      ],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 1,
      totalPages: 1,
      totalGoodsWeightKg: 500,
      totalConvertedQuantities: [],
      groups: [],
      canViewMaterialValue: false,
    );

    await _pump(tester, WeighStationSummaryTable(summary: summary));

    expect(find.text('-'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary hiển thị message và không bỏ số quy đổi hợp lệ', (
    tester,
  ) async {
    const summary = WeighStationSummary(
      items: [
        WeighStationSummaryItem(
          stt: 1,
          goodsName: 'Xi Măng Rời PCB40',
          goodsWeightKg: 280010,
          convertedQuantities: [],
          conversionMessage: 'Chưa xác định',
        ),
        WeighStationSummaryItem(
          stt: 2,
          goodsName: 'Dữ liệu hỗn hợp',
          goodsWeightKg: 175120,
          convertedQuantities: [
            WeighStationConvertedQuantity(quantity: 175.12, unit: 'tấn'),
          ],
          conversionMessage: 'Chưa xác định',
        ),
      ],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 2,
      totalPages: 1,
      totalGoodsWeightKg: 455130,
      totalConvertedQuantities: [
        WeighStationConvertedQuantity(quantity: 175.12, unit: 'tấn'),
      ],
      groups: [],
      canViewMaterialValue: false,
    );

    await _pump(tester, WeighStationSummaryTable(summary: summary));

    expect(find.text('Chưa xác định'), findsNWidgets(2));
    expect(find.text('175,12 tấn'), findsOneWidget);
    expect(find.text('-'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tổng bỏ groups cũ và dùng trực tiếp các field tổng backend', (
    tester,
  ) async {
    const summary = WeighStationSummary(
      items: [],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 0,
      totalPages: 0,
      totalGoodsWeightKg: 1590590,
      totalConvertedQuantities: [
        WeighStationConvertedQuantity(quantity: 1587.45, unit: 'tấn'),
        WeighStationConvertedQuantity(quantity: 3140, unit: 'L'),
        WeighStationConvertedQuantity(quantity: 100, unit: 'm³'),
      ],
      groups: [
        WeighStationSummaryGroup(
          keyName: 'NHAP_CAT_DA',
          label: 'Nhập hàng - Cát, đá',
          goodsWeightKg: 4132780,
          convertedQuantities: [
            WeighStationConvertedQuantity(quantity: 4070.75, unit: 'tấn'),
          ],
        ),
        WeighStationSummaryGroup(
          keyName: 'XUAT_HANG',
          label: 'Xuất hàng',
          goodsWeightKg: 500,
          convertedQuantities: [],
        ),
      ],
      canViewMaterialValue: false,
    );

    await _pump(
      tester,
      WeighStationSummaryOverview(summary: summary),
      size: const Size(320, 720),
    );

    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('1.590.590 kg'), findsOneWidget);
    expect(find.text('1.587,45 tấn'), findsOneWidget);
    expect(find.text('3.140 L'), findsOneWidget);
    expect(find.text('100 m³'), findsOneWidget);
    expect(find.text('Nhập hàng - Cát, đá'), findsNothing);
    expect(find.text('Xuất hàng'), findsNothing);
    expect(find.text('4.132.780 kg'), findsNothing);
    expect(find.text('4.070,75 tấn'), findsNothing);
    expect(find.text('4.827,45'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tổng quy đổi rỗng hiển thị gạch ngang', (tester) async {
    const summary = WeighStationSummary(
      items: [],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 0,
      totalPages: 0,
      totalGoodsWeightKg: 500,
      totalConvertedQuantities: [],
      groups: [],
      canViewMaterialValue: false,
    );

    await _pump(
      tester,
      WeighStationSummaryOverview(summary: summary),
      size: const Size(320, 480),
    );

    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('500 kg'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile hiển thị phiếu cân dạng bảng và kéo ngang', (
    tester,
  ) async {
    await _pump(
      tester,
      WeighStationDetailTable(
        page: WeighStationPage(
          items: const [
            WeighStationItem(
              stt: 1,
              id: 'mobile-ticket',
              ticketNumber: 154613,
              ticketCode: 'PC-154613',
              vehiclePlate: '89 H 02319',
              driverName: 'Lái xe A',
              goodsName: 'Đá 1x2',
              weighingType: 'Nhập hàng',
              inboundWeightKg: 67140,
              outboundWeightKg: 20150,
              goodsWeightKg: 46990,
              convertedQuantity: 46.99,
              convertedUnit: 'tấn',
              materialValueVnd: 12500000,
              hasConversionConfiguration: true,
            ),
          ],
          pageNumber: 1,
          pageSize: 10,
          totalCount: 1,
          totalPages: 1,
          canViewMaterialValue: true,
        ),
      ),
      size: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('weigh-station-detail-card-mobile-ticket'),
      ),
      findsNothing,
    );
    final horizontalScroll = find.byKey(
      const ValueKey<String>('weigh-station-detail-horizontal-scroll'),
    );
    expect(horizontalScroll, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(horizontalScroll).scrollDirection,
      Axis.horizontal,
    );
    final pinnedIndex = find.byKey(
      const ValueKey<String>('weigh-station-detail-pinned-index'),
    );
    final pinnedTicketNumber = find.byKey(
      const ValueKey<String>('weigh-station-detail-pinned-ticket-number'),
    );
    expect(pinnedIndex, findsOneWidget);
    expect(pinnedTicketNumber, findsOneWidget);
    expect(find.text('Mã phiếu'), findsNothing);
    expect(find.text('PC-154613'), findsNothing);
    expect(find.text('154613'), findsOneWidget);
    final pinnedIndexLeftBeforeDrag = tester.getTopLeft(pinnedIndex).dx;
    final pinnedTicketLeftBeforeDrag = tester.getTopLeft(pinnedTicketNumber).dx;
    expect(find.text('89 H 02319'), findsOneWidget);

    final scrollable = find.descendant(
      of: horizontalScroll,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    await tester.drag(horizontalScroll, const Offset(-1200, 0));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.getTopLeft(pinnedIndex).dx, pinnedIndexLeftBeforeDrag);
    expect(
      tester.getTopLeft(pinnedTicketNumber).dx,
      pinnedTicketLeftBeforeDrag,
    );
    expect(find.text('154613'), findsOneWidget);
    expect(find.text('46.990'), findsOneWidget);
    expect(find.text('46,99 tấn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile card không đọc nhầm offset cuộn thành trạng thái mở rộng',
    (tester) async {
      tester.view.physicalSize = const Size(240, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bucket = PageStorageBucket();
      const sharedScrollKey = PageStorageKey<String>(
        'weigh-station-screen-scroll',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PageStorage(
            bucket: bucket,
            child: const SingleChildScrollView(
              key: sharedScrollKey,
              child: SizedBox(height: 2000),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: PageStorage(
            bucket: bucket,
            child: SingleChildScrollView(
              key: sharedScrollKey,
              child: WeighStationDetailTable(
                page: WeighStationPage(
                  items: const [
                    WeighStationItem(
                      stt: 1,
                      id: 'page-storage-ticket',
                      ticketNumber: 1,
                      hasConversionConfiguration: false,
                    ),
                  ],
                  pageNumber: 1,
                  pageSize: 10,
                  totalCount: 1,
                  totalPages: 1,
                  canViewMaterialValue: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile tổng hợp dùng KPI và bảng kéo ngang', (tester) async {
    const summary = WeighStationSummary(
      items: [
        WeighStationSummaryItem(
          stt: 1,
          goodsName: 'Đá 1x2',
          goodsWeightKg: 299980,
          convertedQuantities: [
            WeighStationConvertedQuantity(quantity: 299.98, unit: 'tấn'),
          ],
          ticketCount: 5,
          materialValueVnd: 48000000,
        ),
      ],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 3,
      totalPages: 1,
      totalGoodsWeightKg: 480620,
      totalConvertedQuantities: [
        WeighStationConvertedQuantity(quantity: 422.91, unit: 'tấn'),
      ],
      topGoods: WeighStationTopGoods(
        goodsName: 'Đá 1x2',
        goodsWeightKg: 299980,
      ),
      groups: [],
      totalMaterialValueVnd: 48000000,
      canViewMaterialValue: true,
    );

    await _pump(
      tester,
      Column(
        children: [
          WeighStationSummaryOverview(summary: summary),
          WeighStationSummaryTable(summary: summary),
        ],
      ),
      size: const Size(390, 1200),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('weigh-station-summary-horizontal-scroll'),
      ),
      findsOneWidget,
    );
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Tổng số loại hàng'), findsOneWidget);
    expect(find.text('3 loại'), findsOneWidget);
    expect(find.text('Loại hàng nhiều nhất'), findsOneWidget);
    expect(find.text('299,98 tấn'), findsOneWidget);
    expect(find.text('48.000.000 ₫'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}
