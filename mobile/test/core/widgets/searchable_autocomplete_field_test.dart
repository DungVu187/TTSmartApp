import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/widgets/searchable_autocomplete_field.dart';

void main() {
  testWidgets('filters, selects and clears long-list options', (tester) async {
    String? selectedOption;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 320,
                child: SearchableAutocompleteField<String>(
                  options: const ['51A-12345', '30B-67890', '29C-11111'],
                  selectedOption: selectedOption,
                  displayStringForOption: (option) => option,
                  onSelected: (option) {
                    setState(() => selectedOption = option);
                  },
                  onCleared: () {
                    setState(() => selectedOption = null);
                  },
                  hintText: 'Tất cả xe',
                  labelText: 'Xe',
                  prefixIcon: Icons.local_shipping_outlined,
                  compact: true,
                ),
              );
            },
          ),
        ),
      ),
    );

    final input = find.byType(TextFormField);
    await tester.tap(input);
    await tester.enterText(input, '12345');
    await tester.pump();

    expect(find.text('51A-12345'), findsOneWidget);
    expect(find.text('30B-67890'), findsNothing);

    await tester.tap(find.text('51A-12345'));
    await tester.pumpAndSettle();

    expect(selectedOption, '51A-12345');
    expect(find.widgetWithText(TextFormField, '51A-12345'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa lựa chọn'));
    await tester.pumpAndSettle();

    expect(selectedOption, isNull);
    expect(find.widgetWithText(TextFormField, '51A-12345'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
