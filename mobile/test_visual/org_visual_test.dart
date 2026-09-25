import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/presentation/screens/companies_screen.dart';
import 'package:ttsmart_mobile/features/station_management/presentation/screens/stations_screen.dart';

import 'app_fixture.dart';
import 'fixtures_org.dart';
import 'harness.dart';

/// Figma "Tổ chức" B01–B05.
void main() {
  setUpAll(loadVisualFonts);

  testWidgets('B01 companies + B02 company detail', (tester) async {
    await pumpVisualScreen(
      tester,
      CompaniesScreen(repository: VisualCompanyRepository()),
    );
    await snap('B01_companies');
    await tester.tap(find.text('Công ty CP Xây dựng Hòa Bình'));
    await tester.pumpAndSettle();
    await snap('B02_company_detail');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await snap('B02_company_detail_bottom');
  });

  testWidgets('B03 stations + B04 filters + B05 detail', (tester) async {
    await pumpVisualScreen(
      tester,
      StationsScreen(
        repository: VisualStationRepository(),
        companyRepository: VisualCompanyRepository(),
      ),
    );
    await snap('B03_stations');
    await tester.tap(find.byTooltip('Bộ lọc'));
    await tester.pumpAndSettle();
    await snap('B04_station_filters');
    await tester.tapAt(const Offset(195, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trạm Hà Nam'));
    await tester.pumpAndSettle();
    await snap('B05_station_detail');
  });
}
