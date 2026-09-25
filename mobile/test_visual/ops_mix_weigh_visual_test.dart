import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/mix_design_management/presentation/screens/mix_designs_screen.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/presentation/screens/weigh_station_screen.dart';

import 'app_fixture.dart';
import 'fixtures_ops.dart';
import 'fixtures_org.dart';
import 'harness.dart';

/// Figma "Vận hành" C09–C14 (mix designs + weigh station).
void main() {
  setUpAll(loadVisualFonts);

  Future<void> openMix(WidgetTester tester) => pumpVisualScreen(
    tester,
    MixDesignsScreen(
      repository: VisualMixDesignRepository(),
      companyRepository: VisualCompanyRepository(),
    ),
    admin: false,
  );

  Future<void> openWeigh(WidgetTester tester) => pumpVisualScreen(
    tester,
    WeighStationScreen(
      repository: VisualWeighStationRepository(),
      companyRepository: VisualCompanyRepository(),
      now: () => DateTime(2026, 9, 21, 17, 30),
    ),
    admin: false,
  );

  testWidgets('C09 mix designs', (tester) async {
    await openMix(tester);
    await snap('C09_mix_designs');
  });

  testWidgets('C10 mix design detail', (tester) async {
    await openMix(tester);
    await tester.tap(find.text('M300').first);
    await tester.pumpAndSettle();
    await snap('C10_mix_design_detail');
  });

  testWidgets('C11 weigh tickets', (tester) async {
    await openWeigh(tester);
    await snap('C11_weigh_tickets');
  });

  testWidgets('C12 weigh ticket detail', (tester) async {
    await openWeigh(tester);
    await tester.tap(find.text('90C-221.08'));
    await tester.pumpAndSettle();
    await snap('C12_weigh_ticket_detail');
  });

  testWidgets('C13 weigh summary', (tester) async {
    await openWeigh(tester);
    await tester.tap(find.text('Tổng hợp'));
    await tester.pumpAndSettle();
    await snap('C13_weigh_summary');
  });

  testWidgets('C14 weigh filters', (tester) async {
    await openWeigh(tester);
    await tapKey(tester, 'weigh-station-advanced-filters');
    await snap('C14_weigh_filters');
  });
}
