import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';

Map<String, Object?> sessionJson({String activeKey = '100000001'}) => {
  'accessToken': 'token',
  'expiresAtUtc': '2026-07-24T12:00:00Z',
  'user': {
    'id': 7,
    'userName': 'admin',
    'fullName': 'Quản trị',
    'email': 'admin@example.test',
    'code': 'AD001',
    'phone': null,
    'companyId': 1,
    'departmentId': null,
    'positionId': 2,
    'unitId': null,
    'branchId': 'HQ',
    'status': 1,
  },
  'roles': [
    {'id': 3, 'code': 'ADMIN', 'name': 'Quản trị viên', 'levelRole': 1},
  ],
  'functions': [
    {
      'id': 10,
      'parentFunctionId': null,
      'code': 'QLND',
      'name': 'Quản lý người dùng',
      'url': '/users',
      'location': 1,
      'icon': 'people',
      'activeKey': activeKey,
      'permissions': {
        'view': true,
        'create': false,
        'update': false,
        'delete': false,
        'import': false,
        'export': false,
        'print': false,
        'other': false,
        'dSach': true,
        'full': false,
      },
    },
  ],
  'roleFunctions': [
    {
      'roleId': 3,
      'roleCode': 'ADMIN',
      'roleName': 'Quản trị viên',
      'functionRoleId': 30,
      'functionId': 10,
      'parentFunctionId': null,
      'functionCode': 'QLND',
      'functionName': 'Quản lý người dùng',
      'url': '/users',
      'type': 1,
      'activeKey': activeKey,
      'permissions': {
        'view': true,
        'create': false,
        'update': false,
        'delete': false,
        'import': false,
        'export': false,
        'print': false,
        'other': false,
        'dSach': true,
        'full': false,
      },
    },
  ],
};

void main() {
  test('parse login/session, role object and roleFunctions', () {
    final result = LoginResult.fromJson(sessionJson());

    expect(result.accessToken, 'token');
    expect(result.session.user.id, 7);
    expect(result.session.user.fullName, 'Quản trị');
    expect(result.session.roles.single.id, 3);
    expect(result.session.roles.single.code, 'ADMIN');
    expect(result.session.hasRole('admin'), isTrue);
    expect(result.session.roleFunctions.single.functionRoleId, 30);
    expect(result.session.hasPermission('qlnd', AccessPermission.view), isTrue);
    expect(
      result.session.hasPermission('QLND', AccessPermission.dSach),
      isTrue,
    );
  });

  test('ActiveKey được chuẩn hóa thành đúng 9 quyền', () {
    final session = LoginResult.fromJson(sessionJson(activeKey: '111000001'));
    final permissions = session.session.functions.single.permissions;

    expect(permissions.activeKey, '111000001');
    expect(permissions.full, isFalse);
    expect(permissions.view, isTrue);
    expect(permissions.create, isTrue);
    expect(permissions.update, isTrue);
    expect(permissions.delete, isFalse);
    expect(permissions.dSach, isTrue);
  });

  test('ActiveKey sai contract thì không cấp quyền', () {
    final session = LoginResult.fromJson(sessionJson(activeKey: '101'));

    expect(
      session.session.functions.single.permissions,
      const PermissionSet.none(),
    );
  });

  test(
    'AuthRepository đổi response sai cấu trúc thành invalidResponse',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('http://localhost:5052'),
        timeout: const Duration(seconds: 1),
        httpClient: MockClient((_) async => http.Response('{user:{}}', 200)),
      )..accessToken = 'token';
      final repository = AuthRepository(client);

      await expectLater(
        repository.getCurrentSession(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiFailureType.invalidResponse,
          ),
        ),
      );
    },
  );
}
