import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_fixture.dart';
import 'harness.dart';

/// Figma "Vận hành" C01–C04, C15, C17 (statistics + orders filters).
void main() {
  setUpAll(loadVisualFonts);

  Future<void> openStatistics(WidgetTester tester) async {
    await pumpVisualShell(tester, admin: false);
    await tapKey(tester, 'shell-nav-statistics');
  }

  testWidgets('C01 statistics', (tester) async {
    await openStatistics(tester);
    await snap('C01_statistics');
  });

  testWidgets('C02 batch detail', (tester) async {
    await openStatistics(tester);
    await tester.tap(find.text('Công ty CP Xây dựng Hòa Bình').first);
    await tester.pumpAndSettle();
    await snap('C02_batch_detail');
    await tester.scrollUntilVisible(
      find.text('SS = Thực tế + T − ĐM. Đơn vị kg, riêng nước tính theo lít.'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await snap('C02_batch_detail_bottom');
  });

  testWidgets('C03 statistics summary', (tester) async {
    await openStatistics(tester);
    await tapKey(tester, 'statistics-summary-tile');
    await snap('C03_statistics_summary');
  });

  testWidgets('C04 extra filters', (tester) async {
    await openStatistics(tester);
    await tapKey(tester, 'statistics-extra-filters');
    await tapKey(tester, 'statistics-customer');
    await tester.tap(find.text('Công ty CP Xây dựng Hòa Bình').last);
    await tester.pumpAndSettle();
    await snap('C04_extra_filters');
  });

  testWidgets('C15 date range picker', (tester) async {
    await openStatistics(tester);
    await tapKey(tester, 'statistics-date-range');
    await tapKey(tester, 'statistics-date-preset-sevenDays');
    await snap('C15_date_range');
  });

  testWidgets('C17 order filters', (tester) async {
    await pumpVisualShell(tester, admin: true);
    await tapKey(tester, 'shell-nav-orders');
    await tapKey(tester, 'order-report-filters-button');
    await snap('C17_order_filters');
  });
}
