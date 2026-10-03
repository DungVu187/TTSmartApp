import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/core/ui/app_ui.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/user_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/controllers/functions_controller.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/controllers/users_controller.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/screens/function_form_screen.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/screens/user_form_screen.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/screens/users_screen.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';

import '../../support/phone_viewport.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _CompanyAccountController extends AppController {
  _CompanyAccountController(ApiClient apiClient)
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

  int sessionRefreshes = 0;

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 7,
      userName: 'company-owner',
      fullName: 'Company Owner',
      email: null,
      code: null,
      phone: null,
      companyId: 10,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: '20',
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) => true;

  @override
  bool hasRole(String roleCode) => false;

  @override
  Future<void> refreshCurrentSession() async => sessionRefreshes++;
}

Map<String, Object?> _function(
  int id,
  String code,
  String name, {
  int? parent,
}) => <String, Object?>{
  'id': id,
  'parentFunctionId': parent,
  'code': code,
  'name': name,
  'status': 1,
  'isActive': true,
  'childCount': 0,
  'assignedRoleCount': 0,
  'grantedRoleCount': 0,
};

ApiClient _apiClient(Object? Function(http.Request request) respond) =>
    ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        final body = respond(request);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    )..accessToken = 'test-token';

/// Opens [screen] from a launcher so the form's pop has a route to return to.
Future<void> _pumpFromLauncher(
  WidgetTester tester,
  AppController controller,
  Widget screen,
) async {
  // Like the app, AppScope sits above the navigator so pushed routes see it.
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở form'));
  await tester.pumpAndSettle();
}

Finder _input(String label) => find.descendant(
  of: find.widgetWithText(LabeledTextField, label),
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets('user form groups fields like S08 and validates required ones', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final apiClient = _apiClient(
      (request) => switch (request.url.path) {
        '/api/users/assignable-roles' => <Object?>[],
        '/api/branches' => <String, Object?>{
          'items': <Object?>[],
          'pageNumber': 1,
          'pageSize': 100,
          'totalCount': 0,
          'totalPages': 0,
        },
        _ => throw StateError('Unexpected request: ${request.url}'),
      },
    );
    final controller = _CompanyAccountController(apiClient);
    addTearDown(controller.dispose);

    await _pumpFromLauncher(
      tester,
      controller,
      UserFormScreen(
        controller: UsersController(AccessManagementRepository(apiClient)),
        companyRepository: ApiCompanyRepository(apiClient),
        stationRepository: ApiStationRepository(apiClient),
      ),
    );

    expect(find.text('Thêm người dùng'), findsOneWidget);
    // Company accounts are fixed to their company: no company field.
    expect(find.byKey(const ValueKey('user-form-company')), findsNothing);
    expect(find.text('Chọn một hoặc nhiều trạm'), findsOneWidget);
    final account = tester.getTopLeft(find.text('TÀI KHOẢN')).dy;
    final organization = tester.getTopLeft(find.text('TỔ CHỨC')).dy;
    expect(account, lessThan(organization));

    await tester.tap(find.byKey(const ValueKey('access-form-save')));
    await tester.pumpAndSettle();

    expect(find.text('Tên đăng nhập là bắt buộc.'), findsOneWidget);
    expect(find.text('Mật khẩu phải có từ 4 đến 200 ký tự.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('LIÊN HỆ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa chọn vai trò'), findsOneWidget);
    expect(find.text('Vai trò được gửi bằng ID số nguyên.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('function form picks the parent from a sheet and posts it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    Map<String, Object?>? posted;
    final apiClient = _apiClient((request) {
      if (request.method == 'POST' && request.url.path == '/api/functions') {
        posted = jsonDecode(request.body) as Map<String, Object?>;
        return _function(3, 'BCDH', 'Báo cáo đơn hàng', parent: 2);
      }
      if (request.url.path == '/api/functions') {
        return <Object?>[
          _function(1, 'HT', 'Hệ thống'),
          _function(2, 'QLND', 'Quản lý người dùng', parent: 1),
        ];
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final controller = _CompanyAccountController(apiClient);
    addTearDown(controller.dispose);

    await _pumpFromLauncher(
      tester,
      controller,
      FunctionFormScreen(
        controller: FunctionsController(AccessManagementRepository(apiClient)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('access-form-save')));
    await tester.pumpAndSettle();
    expect(find.text('Mã chức năng là bắt buộc.'), findsOneWidget);
    expect(find.text('Tên chức năng là bắt buộc.'), findsOneWidget);

    await tester.enterText(_input('Mã chức năng *'), 'BCDH');
    await tester.enterText(_input('Tên chức năng *'), 'Báo cáo đơn hàng');
    await tester.tap(find.byKey(const ValueKey('function-form-parent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('— Quản lý người dùng'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý người dùng'), findsOneWidget);

    await tester.enterText(_input('Vị trí'), 'abc');
    await tester.tap(find.byKey(const ValueKey('access-form-save')));
    await tester.pumpAndSettle();
    expect(find.text('Phải là số nguyên.'), findsOneWidget);

    await tester.enterText(_input('Vị trí'), '2');
    await tester.tap(find.byKey(const ValueKey('access-form-save')));
    await tester.pumpAndSettle();

    expect(posted, isNotNull);
    expect(posted!['parentFunctionId'], 2);
    expect(posted!['code'], 'BCDH');
    expect(posted!['name'], 'Báo cáo đơn hàng');
    expect(posted!['location'], 2);
    expect(posted!['url'], isNull);
    expect(controller.sessionRefreshes, 1);
    expect(find.text('Mở form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('users list shows the S14 error, retries, then the S12 empty '
      'state with a create action', (tester) async {
    usePhoneViewport(tester);
    var userRequests = 0;
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        final Object? body = switch (request.url.path) {
          '/api/users' when ++userRequests == 1 => null,
          '/api/users' => <String, Object?>{
            'items': <Object?>[],
            'pageNumber': 1,
            'pageSize': 20,
            'totalCount': 0,
            'totalPages': 0,
          },
          '/api/users/assignable-roles' => <Object?>[],
          '/api/branches' => <String, Object?>{
            'items': <Object?>[],
            'pageNumber': 1,
            'pageSize': 100,
            'totalCount': 0,
            'totalPages': 0,
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        if (body == null) return http.Response('', 503);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    )..accessToken = 'test-token';
    final controller = _CompanyAccountController(apiClient);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light,
          home: UsersScreen(
            companyRepository: ApiCompanyRepository(apiClient),
            stationRepository: ApiStationRepository(apiClient),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không tải được danh sách'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(userRequests, 2);
    expect(find.text('Chưa có người dùng nào'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Thêm người dùng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('removing every station clears them on save instead of '
      'keeping the old ones', (tester) async {
    usePhoneViewport(tester);
    Map<String, Object?>? updated;
    Map<String, Object?> user(String? branchId) => <String, Object?>{
      'id': 42,
      'userName': 'nv-tram',
      'companyId': 10,
      'status': 1,
      'isActive': true,
      'branchId': branchId,
      'roles': <Object?>[],
    };
    Map<String, Object?> station(int id, String name) => <String, Object?>{
      'id': id,
      'companyId': 10,
      'code': 'TRAM_$id',
      'name': name,
      'status': 1,
      'isActive': true,
    };
    final apiClient = _apiClient((request) {
      if (request.method == 'PUT' && request.url.path == '/api/users/42') {
        updated = jsonDecode(request.body) as Map<String, Object?>;
        return user(updated!['branchId'] as String?);
      }
      return switch (request.url.path) {
        '/api/users/assignable-roles' => <Object?>[],
        '/api/branches' => <String, Object?>{
          'items': <Object?>[station(20, 'Trạm A'), station(21, 'Trạm B')],
          'pageNumber': 1,
          'pageSize': 100,
          'totalCount': 2,
          'totalPages': 1,
        },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
    });
    final controller = _CompanyAccountController(apiClient);
    addTearDown(controller.dispose);

    await _pumpFromLauncher(
      tester,
      controller,
      UserFormScreen(
        controller: UsersController(AccessManagementRepository(apiClient)),
        companyRepository: ApiCompanyRepository(apiClient),
        stationRepository: ApiStationRepository(apiClient),
        existingUser: UserResponse.fromJson(user('20,21')),
      ),
    );

    await tester.scrollUntilVisible(
      find.byTooltip('Bỏ trạm').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Bỏ trạm'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Bỏ trạm').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bỏ trạm'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bỏ trạm'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('access-form-save')));
    await tester.pumpAndSettle();

    // The API reads a null branchId as "keep the stations as they are", so
    // an empty selection has to be sent as an explicit empty list.
    expect(updated, isNotNull);
    expect(updated!.containsKey('branchId'), isTrue);
    expect(updated!['branchId'], '');
    expect(find.text('Mở form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a save error scrolls back to the banner at the top', (
    tester,
  ) async {
    // Short screen so the form scrolls, as on a phone with the keyboard.
    usePhoneViewport(tester, size: const Size(360, 520));
    const message =
        'Tài khoản không phải CONGTY phải được gán ít nhất một trạm.';
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, Object?>{'status': 400, 'detail': message}),
            ),
            400,
            headers: {'content-type': 'application/problem+json'},
          );
        }
        final Object body = switch (request.url.path) {
          '/api/users/assignable-roles' => <Object?>[],
          '/api/branches' => <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 20,
                'companyId': 10,
                'code': 'TRAM_20',
                'name': 'Trạm A',
                'status': 1,
                'isActive': true,
              },
            ],
            'pageNumber': 1,
            'pageSize': 100,
            'totalCount': 1,
            'totalPages': 1,
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    )..accessToken = 'test-token';
    final controller = _CompanyAccountController(apiClient);
    addTearDown(controller.dispose);

    await _pumpFromLauncher(
      tester,
      controller,
      UserFormScreen(
        controller: UsersController(AccessManagementRepository(apiClient)),
        companyRepository: ApiCompanyRepository(apiClient),
        stationRepository: ApiStationRepository(apiClient),
        existingUser: UserResponse.fromJson(<String, Object?>{
          'id': 42,
          'userName': 'nv-tram',
          'companyId': 10,
          'status': 1,
          'isActive': true,
          'branchId': '20',
          'roles': <Object?>[],
        }),
      ),
    );

    await tester.scrollUntilVisible(
      find.byTooltip('Bỏ trạm'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Bỏ trạm'));
    await tester.pumpAndSettle();
    // Save from the bottom of the form, far from the banner.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('access-form-save')));
    await tester.pumpAndSettle();

    final banner = find.text(message);
    expect(banner, findsOneWidget);
    // Back at the top: the banner is on screen, below the app bar.
    final top = tester.getTopLeft(banner).dy;
    expect(top, greaterThan(kToolbarHeight));
    expect(
      top,
      lessThan(
        tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
