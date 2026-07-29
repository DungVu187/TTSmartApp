import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/function_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/pagination_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/role_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/user_models.dart';

Map<String, Object?> userJson() => {
  'id': 11,
  'userName': 'sample-user',
  'fullName': null,
  'email': 'sample@example.test',
  'code': 'U001',
  'avata': null,
  'unitId': null,
  'positionId': 2,
  'departmentId': null,
  'companyId': 1,
  'address': null,
  'phone': '0900000000',
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
  'roles': [
    {
      'id': 4,
      'code': 'USER',
      'name': 'Người dùng',
      'levelRole': null,
      'status': 1,
    },
  ],
};

void main() {
  test('parse response nullable và ID số nguyên', () {
    final page = PagedResponse<UserResponse>.fromJson({
      'items': [userJson()],
      'pageNumber': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    }, UserResponse.fromJson);

    expect(page.items.single.id, 11);
    expect(page.items.single.displayName, 'sample-user');
    expect(page.items.single.roles.single.id, 4);
  });

  test('serialize isActive và roleIds số nguyên', () {
    expect(const SetUserStatusRequest(isActive: false).toJson(), {
      'isActive': false,
    });
    expect(const SetUserRolesRequest(roleIds: [1, 2]).toJson(), {
      'roleIds': [1, 2],
    });
  });

  test('serialize ma trận function bằng activeKey', () {
    final request = SetRoleFunctionsRequest(
      functions: [
        RoleFunctionAssignmentRequest(functionId: 21, activeKey: '111000001'),
      ],
    );

    expect(request.toJson(), {
      'functions': [
        {'functionId': 21, 'activeKey': '111000001'},
      ],
    });
  });

  test('function form chỉ serialize các field backend công bố', () {
    final request = const CreateFunctionRequest(
      parentFunctionId: 1,
      code: 'QLND',
      name: 'Quản lý người dùng',
      url: '/users',
      note: 'Ghi chú',
      location: 1,
      icon: 'people',
    );

    expect(request.toJson(), {
      'parentFunctionId': 1,
      'code': 'QLND',
      'name': 'Quản lý người dùng',
      'url': '/users',
      'note': 'Ghi chú',
      'location': 1,
      'icon': 'people',
    });
  });

  test('invalid activeKey is treated as no permission', () {
    final matrix = RoleFunctionMatrixItemResponse.fromJson({
      'functionId': 21,
      'parentFunctionId': null,
      'code': 'QLND',
      'name': 'Quản lý người dùng',
      'url': null,
      'location': 1,
      'icon': null,
      'functionRoleId': null,
      'isAssigned': false,
      'activeKey': '11111111x',
      'permissions': {'full': true},
    });

    expect(matrix.activeKey, '000000000');
    expect(matrix.permissions.isEmpty, isTrue);
  });
}
