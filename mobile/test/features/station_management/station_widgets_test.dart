import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';
import 'package:ttsmart_mobile/features/station_management/presentation/widgets/station_widgets.dart';

void main() {
  test('station password status never exposes the password value', () {
    const password = 'Secret@123';

    expect(stationPasswordStatus(password), 'Đã thiết lập');
    expect(stationPasswordStatus(password), isNot(contains(password)));
    expect(stationPasswordStatus(''), 'Chưa thiết lập');
  });

  testWidgets('station card shows identity, type and deleted status', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StationListCard(
            station: StationListItem(
              id: 12,
              name: 'Trạm Bình Chánh',
              phone: '0900000000',
              typeTram: 2,
            ),
            isDeleted: true,
          ),
        ),
      ),
    );

    expect(find.text('Trạm Bình Chánh'), findsOneWidget);
    expect(find.text('0900000000'), findsOneWidget);
    expect(find.text('Trạm cân'), findsOneWidget);
    expect(find.text('Đã xóa'), findsOneWidget);
  });

  testWidgets('unknown station type uses a neutral visual state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StationTypeChip(type: null))),
    );

    expect(find.text('Chưa xác định'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  testWidgets('station information remains readable on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(8),
            child: StationSection(
              title: 'Thông tin trạm',
              description: 'Thông tin nhận diện và liên hệ của trạm.',
              child: StationInfoRow(
                label: 'Số điện thoại',
                value: '0900000000',
                icon: Icons.phone_outlined,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Thông tin trạm'), findsOneWidget);
    expect(
      find.text('Thông tin nhận diện và liên hệ của trạm.'),
      findsOneWidget,
    );
    expect(find.text('0900000000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
