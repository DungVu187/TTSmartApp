import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/core/widgets/app_date_picker.dart';

void main() {
  testWidgets('range calendar stays six weeks and blocks future time', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 29, 9, 41);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppDateRangePicker(
                context: context,
                initialStart: DateTime(2026, 9, 21),
                initialEnd: DateTime(2026, 9, 29, 23, 59),
                now: now,
                keyPrefix: 'range-test',
              ),
              child: const Text('Mở lịch'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở lịch'));
    await tester.pumpAndSettle();

    final calendar = find.byKey(
      const ValueKey<String>('range-test-calendar-2026-9-21'),
    );
    final height = tester.getSize(calendar).height;
    expect(find.text('29/09/2026 09:41'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('range-test-month-previous')),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(calendar).height, height);

    await tester.tap(
      find.byKey(const ValueKey<String>('range-test-month-year')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('range-test-month-10')),
          )
          .onTap,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('range-test-select-year')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('range-test-year-2027')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('range-test-year-2025')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('range-test-month-12')));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 12, 2025'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('range-test-to-field')));
    await tester.pumpAndSettle();
    final hour = find.descendant(
      of: find.byKey(const ValueKey<String>('range-test-hour')),
      matching: find.byType(DropdownButton<int>),
    );
    final minute = find.descendant(
      of: find.byKey(const ValueKey<String>('range-test-minute')),
      matching: find.byType(DropdownButton<int>),
    );
    expect(
      tester.widget<DropdownButton<int>>(hour).items![10].enabled,
      isFalse,
    );
    expect(
      tester.widget<DropdownButton<int>>(minute).items![42].enabled,
      isFalse,
    );
  });

  testWidgets('single-date expiry picker still allows future months', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 29),
                firstDate: DateTime(2026, 9, 1),
                lastDate: DateTime(2026, 11, 30),
                title: 'Hạn sử dụng',
                keyPrefix: 'expiry-test',
              ),
              child: const Text('Mở hạn sử dụng'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở hạn sử dụng'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('expiry-test-month-year')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('expiry-test-month-10')),
          )
          .onTap,
      isNotNull,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('expiry-test-month-10')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tháng 10, 2026'), findsOneWidget);
  });
}
