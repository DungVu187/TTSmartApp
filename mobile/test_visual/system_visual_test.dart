import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ttsmart_mobile/features/shell/presentation/screens/no_access_screen.dart';

import 'app_fixture.dart';
import 'harness.dart';

/// Figma "Hệ thống v3" S02–S17.
void main() {
  setUpAll(loadVisualFonts);

  Future<void> openModule(
    WidgetTester tester,
    String module, {
    Map<String, Object? Function(http.Request)> routes = const {},
  }) async {
    await pumpVisualShell(tester, routes: routes);
    await tapKey(tester, 'shell-nav-system');
    await tapKey(tester, 'system-$module');
  }

  testWidgets('S02 users', (tester) async {
    await openModule(tester, 'users');
    await snap('S02_users');
  });

  testWidgets('S03 user detail + S16 delete confirm', (tester) async {
    await openModule(tester, 'users');
    await tester.tap(find.text('Nguyễn Hoàng Nam'));
    await tester.pumpAndSettle();
    await snap('S03_user_detail');
    await tester.ensureVisible(find.text('Xóa người dùng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa người dùng'));
    await tester.pumpAndSettle();
    await snap('S16_delete_confirm');
  });

  testWidgets('S08 user form + S09 station picker', (tester) async {
    await openModule(tester, 'users');
    await tester.tap(find.text('Nguyễn Hoàng Nam'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa thông tin'));
    await tester.pumpAndSettle();
    await snap('S08_user_form');
    await tapKey(tester, 'user-form-stations');
    await snap('S09_station_picker');
  });

  testWidgets('S04 roles + S05 role detail', (tester) async {
    await openModule(tester, 'roles');
    await snap('S04_roles');
    await tester.tap(find.text('Chủ doanh nghiệp'));
    await tester.pumpAndSettle();
    await snap('S05_role_detail');
  });

  testWidgets('S06 role functions + S07 permissions + S17 bulk', (
    tester,
  ) async {
    await openModule(tester, 'roles');
    await tester.tap(find.text('Chủ doanh nghiệp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quyền chức năng'));
    await tester.pumpAndSettle();
    await snap('S06_role_functions');
    await tester.tap(find.text('Quản lý người dùng'));
    await tester.pumpAndSettle();
    await snap('S07_function_permissions');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapKey(tester, 'role-functions-bulk');
    await snap('S17_bulk_apply');
  });

  testWidgets('S10 functions + S11 function form', (tester) async {
    await openModule(tester, 'functions');
    await snap('S10_functions');
    await tester.tap(find.text('Hệ thống'));
    await tester.pumpAndSettle();
    await snap('S10_functions_folder');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bảng giá'));
    await tester.pumpAndSettle();
    await snap('S10_function_detail');
    await tester.scrollUntilVisible(
      find.text('Sửa chức năng'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Sửa chức năng'));
    await tester.pumpAndSettle();
    await snap('S11_function_form');
  });

  testWidgets('S15 no access', (tester) async {
    await pumpVisualScreen(tester, const NoAccessScreen());
    await snap('S15_no_access');
  });

  testWidgets('S12 empty users', (tester) async {
    await openModule(
      tester,
      'users',
      routes: {
        r'GET /api/users': (_) => <String, Object?>{
          'items': <Object?>[],
          'pageNumber': 1,
          'pageSize': 20,
          'totalCount': 0,
          'totalPages': 0,
        },
      },
    );
    await snap('S12_empty');
  });

  testWidgets('S13 loading users', (tester) async {
    final never = Completer<Object?>();
    await openModule(
      tester,
      'users',
      routes: {r'GET /api/users': (_) => never.future},
    );
    await snap('S13_loading');
    // Let the pending request hit the client timeout before teardown.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('S14 load error', (tester) async {
    await openModule(
      tester,
      'users',
      routes: {r'GET /api/users': (_) => throw StateError('network down')},
    );
    await snap('S14_error');
  });
}
