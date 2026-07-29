import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/user_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';

http.Response jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), statusCode);

Map<String, Object?> userResponseJson({int id = 11}) => {
  'id': id,
  'userName': 'sample-user',
  'fullName': 'Người dùng mẫu',
  'email': null,
  'code': null,
  'avata': null,
  'unitId': null,
  'positionId': null,
  'departmentId': null,
  'companyId': null,
  'address': null,
  'phone': null,
  'createdAtUtc': null,
  'updatedAtUtc': null,
  'tokenSinceUtc': null,
  'regEmail': null,
  'roleMax': null,
  'roleLevel': null,
  'isRoleGroup': null,
  'userCreateId': null,
  'userEditId': null,
  'status': 1,
  'isActive': true,
  'branchId': null,
  'roles': [],
};

Map<String, Object?> roleListJson(String page) => {
  'id': int.parse(page),
  'code': 'ROLE$page',
  'name': 'Vai trò $page',
  'note': null,
  'levelRole': null,
  'status': 1,
  'isActive': true,
  'userCount': 0,
  'functionCount': 0,
  'grantedFunctionCount': 0,
};

void main() {
  test('create user gửi payload backend với roleIds số nguyên', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/users');
        expect(jsonDecode(request.body), {
          'userName': 'sample-user',
          'fullName': 'Người dùng mẫu',
          'email': null,
          'code': null,
          'regEmail': null,
          'address': null,
          'phone': null,
          'unitId': null,
          'positionId': null,
          'departmentId': null,
          'companyId': null,
          'roleMax': null,
          'roleLevel': null,
          'isRoleGroup': null,
          'branchId': null,
          'password': 'sample-password',
          'roleIds': [1, 2],
        });
        return jsonResponse(userResponseJson(), 201);
      }),
    )..accessToken = 'token';
    final repository = AccessManagementRepository(client);

    final user = await repository.createUser(
      const CreateUserRequest(
        userName: 'sample-user',
        fullName: 'Người dùng mẫu',
        password: 'sample-password',
        roleIds: [1, 2],
      ),
    );

    expect(user.id, 11);
  });

  test('query status nhận 1 và 99', () async {
    final statuses = <String?>[];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        statuses.add(request.url.queryParameters['status']);
        return jsonResponse({
          'items': [],
          'pageNumber': 1,
          'pageSize': 20,
          'totalCount': 0,
          'totalPages': 0,
        });
      }),
    )..accessToken = 'token';
    final repository = AccessManagementRepository(client);

    await repository.getUsers(status: 1);
    await repository.getUsers(status: 99);

    expect(statuses, ['1', '99']);
  });

  test('getAllRoles phân trang đến trang cuối', () async {
    final requestedPages = <String>[];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        final page = request.url.queryParameters['pageNumber']!;
        requestedPages.add(page);
        return jsonResponse({
          'items': [roleListJson(page)],
          'pageNumber': int.parse(page),
          'pageSize': 100,
          'totalCount': 2,
          'totalPages': 2,
        });
      }),
    )..accessToken = 'token';
    final repository = AccessManagementRepository(client);

    final roles = await repository.getAllRoles();

    expect(requestedPages, ['1', '2']);
    expect(roles.map((role) => role.id), [1, 2]);
  });

  test('getRoleFunctionMatrix gọi đúng endpoint và parse activeKey', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/roles/3/function-matrix');
        return jsonResponse([
          {
            'functionId': 21,
            'parentFunctionId': null,
            'code': 'QLND',
            'name': 'Quản lý người dùng',
            'url': null,
            'location': 1,
            'icon': null,
            'functionRoleId': 31,
            'isAssigned': true,
            'activeKey': '111000001',
            'permissions': {'view': true, 'create': true, 'update': true},
          },
        ]);
      }),
    )..accessToken = 'token';
    final repository = AccessManagementRepository(client);

    final matrix = await repository.getRoleFunctionMatrix(3);

    expect(matrix.single.functionId, 21);
    expect(matrix.single.activeKey, '111000001');
  });

  test('delete function gọi endpoint int và nhận 204', () async {
    final paths = <String>[];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        return http.Response('', 204);
      }),
    )..accessToken = 'token';
    final repository = AccessManagementRepository(client);

    await repository.deleteFunction(21);

    expect(paths, ['DELETE /api/functions/21']);
  });
}
