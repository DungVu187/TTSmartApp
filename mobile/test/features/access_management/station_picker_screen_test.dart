import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/screens/station_picker_screen.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';

void main() {
  testWidgets('lọc trạm và trả về các ID đã chọn', (tester) async {
    Set<int>? result;
    const stations = <StationListItem>[
      StationListItem(
        id: 1,
        name: 'Trạm Long Biên',
        phone: null,
        typeTram: null,
      ),
      StationListItem(id: 2, name: 'Trạm Gia Lâm', phone: null, typeTram: null),
      StationListItem(
        id: 3,
        name: 'Trạm Đông Anh',
        phone: null,
        typeTram: null,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<Set<int>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StationPickerScreen(
                      stations: stations,
                      selectedIds: <int>{1},
                    ),
                  ),
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 / 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Gia Lâm');
    await tester.pumpAndSettle();
    expect(find.text('Trạm Gia Lâm'), findsOneWidget);
    expect(find.text('Trạm Long Biên'), findsNothing);

    await tester.tap(find.text('Trạm Gia Lâm'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / 3'), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(result, <int>{1, 2});
  });
}
