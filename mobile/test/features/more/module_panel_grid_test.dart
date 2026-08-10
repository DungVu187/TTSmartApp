import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/more/presentation/widgets/module_panel_grid.dart';

void main() {
  testWidgets('matches the image 6 compact four-column design', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ModulePanelGrid(
            compactColumnCount: 4,
            items: <ModulePanelItem>[
              ModulePanelItem(
                label: 'Chức năng',
                icon: Icons.settings_outlined,
                accent: AppColors.brandBlue,
                backgroundColor: const Color(0xFFEEF2FF),
                onTap: () {},
              ),
              ModulePanelItem(
                label: 'Phân quyền',
                icon: Icons.admin_panel_settings_outlined,
                accent: const Color(0xFF047857),
                backgroundColor: const Color(0xFFECFDF5),
                onTap: () {},
              ),
              ModulePanelItem(
                label: 'Người dùng',
                icon: Icons.person_outline,
                accent: const Color(0xFF7C3AED),
                backgroundColor: const Color(0xFFF3E8FF),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gridFinder = find.byKey(
      const ValueKey<String>('module-panel-grid-scroll'),
    );
    final grid = tester.widget<GridView>(gridFinder);
    final padding = grid.padding!.resolve(TextDirection.ltr);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(padding.left, 16);
    expect(padding.right, 16);
    expect(delegate.crossAxisCount, 4);
    expect(delegate.crossAxisSpacing, 16);
    expect(delegate.mainAxisExtent, 76);

    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(ValueKey<String>('module-panel-tile-$index')),
        findsOneWidget,
      );
    }
    expect(find.text('(Trống)'), findsNothing);

    final firstTile = find.byKey(const ValueKey<String>('module-panel-tile-0'));
    final secondTile = find.byKey(
      const ValueKey<String>('module-panel-tile-1'),
    );
    expect(
      tester.getRect(secondTile).left - tester.getRect(firstTile).right,
      closeTo(16, 0.01),
    );

    final iconBackground = find.byKey(
      const ValueKey<String>('module-panel-icon-background-0'),
    );
    expect(tester.getSize(iconBackground), const Size(36, 36));
    final iconFinder = find.descendant(
      of: iconBackground,
      matching: find.byType(Icon),
    );
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(iconFinder);
    expect(icon.size, 18);
    expect(icon.color, AppColors.brandBlue);

    final iconDecoration = tester.widget<Container>(iconBackground).decoration;
    expect(iconDecoration, isA<BoxDecoration>());
    final backgroundDecoration = iconDecoration! as BoxDecoration;
    expect(backgroundDecoration.color, const Color(0xFFEEF2FF));
    expect(backgroundDecoration.borderRadius, BorderRadius.circular(10));

    final labelFinder = find.descendant(
      of: firstTile,
      matching: find.text('Chức năng'),
    );
    final label = tester.widget<Text>(labelFinder);
    expect(label.style?.fontSize, 13);
    expect(label.style?.fontWeight, FontWeight.w500);
    expect(label.style?.color, const Color(0xFF1D1F2C));
    expect(
      tester.getRect(labelFinder).top - tester.getRect(iconBackground).bottom,
      closeTo(6, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls inside the panel when module count grows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ModulePanelGrid(
            compactColumnCount: 4,
            items: List<ModulePanelItem>.generate(
              20,
              (index) => ModulePanelItem(
                label: 'Chức năng ${index + 1}',
                icon: Icons.apps_outlined,
                accent: AppColors.brandBlue,
                backgroundColor: const Color(0xFFEEF2FF),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = find.byKey(const ValueKey<String>('module-panel-grid-scroll'));
    final scrollable = find.descendant(
      of: grid,
      matching: find.byType(Scrollable),
    );
    expect(grid, findsOneWidget);
    expect(scrollable, findsOneWidget);

    await tester.drag(grid, const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });
}
