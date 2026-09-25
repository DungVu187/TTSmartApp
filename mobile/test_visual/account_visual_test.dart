import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/core/ui/app_ui.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/presentation/screens/change_password_screen.dart';
import 'package:ttsmart_mobile/features/auth/presentation/screens/session_recovery_screen.dart';
import 'package:ttsmart_mobile/features/auth/presentation/screens/splash_screen.dart';
import 'package:ttsmart_mobile/features/settings/presentation/screens/settings_screen.dart';

import 'fixtures_access.dart';
import 'harness.dart';

/// Figma "Tài khoản" A01–A07.
void main() {
  setUpAll(loadVisualFonts);

  VisualAppController account() => VisualAppController(
    visualApiClient(),
    userName: 'admin.tram01',
    code: 'TT-0012',
    roleOverride: const [
      AuthRole(id: 2, code: 'CONGTY', name: 'Chủ doanh nghiệp', levelRole: 2),
      AuthRole(id: 5, code: 'TRAM', name: 'Quản lý trạm', levelRole: 3),
    ],
  );

  Future<void> pushed(WidgetTester tester, Widget screen) async {
    usePhoneFrame(tester);
    final controller = account();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      visualApp(
        controller,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('A01 splash', (tester) async {
    usePhoneFrame(tester);
    final controller = account();
    addTearDown(controller.dispose);
    await tester.pumpWidget(visualApp(controller, const SplashScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await snap('A01_splash');
  });

  testWidgets('A02 session recovery', (tester) async {
    usePhoneFrame(tester);
    final controller = VisualAppController(
      visualApiClient(),
      startupErrorOverride: const ApiException(
        type: ApiFailureType.network,
        message: 'Không thể kết nối máy chủ.',
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      visualApp(controller, const SessionRecoveryScreen()),
    );
    await tester.pumpAndSettle();
    await snap('A02_session_recovery');
  });

  testWidgets('A03 settings + A04 account + A07 logout', (tester) async {
    await pushed(tester, const SettingsScreen());
    await snap('A03_settings');
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await snap('A07_logout_confirm');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin tài khoản'));
    await tester.pumpAndSettle();
    await snap('A04_account');
  });

  testWidgets('A05 change password + A06 mismatch', (tester) async {
    await pushed(tester, const ChangePasswordScreen());
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '12345678');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await snap('A05_change_password');
    await tester.enterText(fields.at(2), '12345');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await snap('A06_change_password_error');
  });
}
