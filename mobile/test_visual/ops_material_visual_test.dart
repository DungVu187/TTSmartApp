import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/screens/material_report_screen.dart';

import 'app_fixture.dart';
import 'fixtures_material.dart';
import 'fixtures_org.dart';
import 'harness.dart';

/// Figma "Vận hành" C05–C08, C16 (material report).
void main() {
  setUpAll(loadVisualFonts);

  Future<void> open(WidgetTester tester) => pumpVisualScreen(
    tester,
    MaterialReportScreen(
      repository: VisualMaterialRepository(),
      companyRepository: VisualCompanyRepository(),
      isAdmin: false,
    ),
    admin: false,
  );

  testWidgets('C05 material overview', (tester) async {
    await open(tester);
    await snap('C05_material_overview');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await snap('C05_material_overview_bottom');
  });

  testWidgets('C06 material transactions', (tester) async {
    await open(tester);
    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await snap('C06_material_transactions');
  });

  testWidgets('C07 transaction detail', (tester) async {
    await open(tester);
    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập cát vàng – NCC Minh Phát'));
    await tester.pumpAndSettle();
    await snap('C07_transaction_detail');
  });

  testWidgets('C08 material filters', (tester) async {
    await open(tester);
    await tapKey(tester, 'material-filters');
    await snap('C08_material_filters');
  });

  testWidgets('C16 station picker', (tester) async {
    await open(tester);
    await tapKey(tester, 'material-station');
    await snap('C16_station_picker');
  });
}
