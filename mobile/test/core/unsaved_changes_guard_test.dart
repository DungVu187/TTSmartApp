import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/core/ui/app_ui.dart';

import '../support/phone_viewport.dart';

void main() {
  Future<void> openForm(WidgetTester tester, bool Function() isDirty) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => UnsavedChangesGuard(
                      isDirty: isDirty,
                      child: Scaffold(
                        appBar: AppBar(
                          leading: IconButton(
                            tooltip: 'Đóng',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          title: const Text('Form'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở form'));
    await tester.pumpAndSettle();
  }

  testWidgets('leaves at once when nothing was typed', (tester) async {
    await openForm(tester, () => false);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsNothing);
    expect(find.text('Bỏ thay đổi?'), findsNothing);
  });

  testWidgets('asks before throwing typed changes away', (tester) async {
    await openForm(tester, () => true);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsOneWidget);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsNothing);
  });
}
