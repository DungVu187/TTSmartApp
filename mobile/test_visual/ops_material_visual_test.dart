import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/screens/material_report_screen.dart';

import 'app_fixture.dart';
import 'fixtures_material.dart';
import 'fixtures_org.dart';
import 'harness.dart';

/// Figma "Vận hành" C05–C07 (Quản lý vật liệu) and C16 (station picker).
void main() {
  setUpAll(loadVisualFonts);

  Future<void> open(
    WidgetTester tester, {
    bool emptyPeriod = false,
    bool pending = false,
    int? preparingPercent,
  }) => pumpVisualScreen(
    tester,
    MaterialReportScreen(
      repository: VisualMaterialRepository(
        emptyPeriod: emptyPeriod,
        pending: pending,
        preparingPercent: preparingPercent,
      ),
      companyRepository: VisualCompanyRepository(),
      isAdmin: false,
    ),
    admin: false,
    settle: !pending && preparingPercent == null,
  );

  Future<void> scrollDown(WidgetTester tester, double by) async {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -by));
    await tester.pumpAndSettle();
  }

  testWidgets('C05 stock', (tester) async {
    await open(tester);
    await snap('C05_material_stock');
    await scrollDown(tester, 700);
    await snap('C05_material_stock_bottom');
  });

  testWidgets('C05b stock value', (tester) async {
    await open(tester);
    await tester.tap(find.text('Giá trị'));
    await tester.pumpAndSettle();
    await snap('C05b_material_value');
  });

  testWidgets('C05c material detail', (tester) async {
    await open(tester);
    await tapKey(tester, 'material-row-4');
    await snap('C05c_material_detail');
  });

  testWidgets('C05d unit picker, then tấn', (tester) async {
    await open(tester);
    await tapKey(tester, 'material-unit-sand');
    await snap('C05d_material_unit');
    await tester.tap(find.text('tấn'));
    await tester.pumpAndSettle();
    await snap('C05d_material_unit_ton');
  });

  testWidgets('C05e loading', (tester) async {
    await open(tester, pending: true);
    await snap('C05e_material_loading');
  });

  testWidgets('C05f first read of the station', (tester) async {
    await open(tester, preparingPercent: 42);
    await snap('C05f_material_preparing');
  });

  testWidgets('C06 chart', (tester) async {
    await open(tester);
    await tester.tap(find.text('Biểu đồ'));
    await tester.pumpAndSettle();
    await snap('C06_material_chart');
    await scrollDown(tester, 700);
    await snap('C06_material_chart_bottom');
  });

  testWidgets('C07 vouchers and detail', (tester) async {
    await open(tester);
    await tester.tap(find.text('Phiếu'));
    await tester.pumpAndSettle();
    await snap('C07_material_vouchers');
    await tester.tap(find.text('Nhập hàng từ trạm cân'));
    await tester.pumpAndSettle();
    await snap('C07b_material_voucher_detail');
  });

  testWidgets('C07c vouchers, empty period', (tester) async {
    await open(tester, emptyPeriod: true);
    await tester.tap(find.text('Phiếu'));
    await tester.pumpAndSettle();
    await snap('C07c_material_vouchers_empty');
  });

  testWidgets('C16 station picker', (tester) async {
    await open(tester);
    await tapKey(tester, 'material-station');
    await snap('C16_station_picker');
  });
}
