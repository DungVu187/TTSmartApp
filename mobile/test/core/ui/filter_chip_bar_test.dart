import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/core/ui/ui_controls.dart';

import '../../support/phone_viewport.dart';

void main() {
  for (final width in <double>[360, 390, 412]) {
    for (final scale in <double>[1, 1.3]) {
      testWidgets('filters fit ${width.toInt()}px at ${scale}x text', (
        tester,
      ) async {
        usePhoneViewport(tester, size: Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilterChipBar(
                      firstRowCount: 2,
                      children: [
                        FilterChipButton(
                          key: const ValueKey('company'),
                          label:
                              'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
                          onTap: () {},
                        ),
                        FilterChipButton(
                          key: const ValueKey('station'),
                          label: 'Trạm trộn bê tông Hà Nam số 1',
                          onTap: () {},
                        ),
                        FilterChipButton(
                          key: const ValueKey('date'),
                          label: '01/09 – 29/09',
                          onTap: () {},
                        ),
                        FilterChipButton(
                          key: const ValueKey('employee'),
                          label: 'Nhân viên kinh doanh',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
        expect(rect('company').top, rect('station').top);
        expect(rect('date').top, rect('employee').top);
        expect(rect('date').top, greaterThan(rect('company').bottom));
        for (final key in ['company', 'station', 'date', 'employee']) {
          expect(rect(key).left, greaterThanOrEqualTo(20));
          expect(rect(key).right, lessThanOrEqualTo(width - 20));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
