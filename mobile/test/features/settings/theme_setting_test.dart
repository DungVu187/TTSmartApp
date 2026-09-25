import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/core/theme/theme_controller.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/home/presentation/widgets/dashboard_widgets.dart';
import 'package:ttsmart_mobile/features/settings/presentation/screens/settings_screen.dart';

import '../../support/phone_viewport.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _SignedInController extends AppController {
  _SignedInController(ApiClient api)
    : super(
        apiClient: api,
        authRepository: AuthRepository(api),
        accessManagementRepository: AccessManagementRepository(api),
        tokenStorage: _MemoryTokenStorage(),
      );

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: 'dungvd',
      fullName: 'Vũ Đức Dũng',
      email: null,
      code: null,
      phone: null,
      companyId: 3,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: null,
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );
}

void main() {
  test('ThemeController reads and saves the choice', () async {
    final store = MemoryThemePreferenceStore('dark');
    final controller = ThemeController(store: store);
    expect(controller.mode, ThemeMode.system);

    await controller.load();
    expect(controller.mode, ThemeMode.dark);

    await controller.setMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);
    expect(await store.read(), 'light');
  });

  test('ThemeController falls back to the system setting', () async {
    final controller = ThemeController(
      store: MemoryThemePreferenceStore('something-else'),
      initialMode: ThemeMode.dark,
    );
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  testWidgets('Cài đặt: Sáng / Tối / Theo hệ thống switch the theme', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final api = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((_) async => throw StateError('no network')),
    );
    final app = _SignedInController(api);
    addTearDown(app.dispose);
    final theme = ThemeController();
    addTearDown(theme.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: ThemeScope(
          controller: theme,
          child: ListenableBuilder(
            listenable: theme,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: theme.mode,
              home: const SettingsScreen(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('GIAO DIỆN'), findsOneWidget);
    expect(find.text('Tự đổi theo cài đặt của điện thoại'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-theme-dark')));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('GIAO DIỆN'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const ValueKey('settings-theme-light')));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('GIAO DIỆN'))).brightness,
      Brightness.light,
    );
  });

  test('chart labels fall on round hours and days', () {
    final hours = [
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}H',
    ];
    expect(
      AreaTrendChart.labelIndices(hours).map((index) => hours[index]),
      ['00H', '04H', '08H', '12H', '16H', '20H'],
    );
    final days = [
      for (var day = 1; day <= 30; day++) day.toString().padLeft(2, '0'),
    ];
    expect(
      AreaTrendChart.labelIndices(days).map((index) => days[index]),
      ['01', '05', '10', '15', '20', '25', '30'],
    );
  });
}
