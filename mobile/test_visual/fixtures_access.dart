// JSON routes for the access-management API (Figma "Hệ thống" S01–S17).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';

typedef VisualRoute = Object? Function(http.Request request);

Map<String, Object?> _page(List<Object?> items, {int? total}) =>
    <String, Object?>{
      'items': items,
      'pageNumber': 1,
      'pageSize': 20,
      'totalCount': total ?? items.length,
      'totalPages': 1,
    };

const _owner = <String, Object?>{
  'id': 1,
  'code': 'CONGTY2.0',
  'name': 'Chủ doanh nghiệp',
  'levelRole': 2,
  'status': 1,
};

Map<String, Object?> visualUser(
  int id,
  String userName,
  String fullName, {
  String? email,
  String? phone,
  String? address,
  String branchId = '31,32',
  bool active = true,
}) => <String, Object?>{
  'id': id,
  'userName': userName,
  'fullName': fullName,
  'email': email ?? '$userName@ttsmart.vn',
  'code': 'NV${id.toString().padLeft(3, '0')}',
  'companyId': 3,
  'address': address,
  'phone': phone,
  'status': active ? 1 : 0,
  'isActive': active,
  'branchId': branchId,
  'roles': const [_owner],
};

final visualUsers = <Object?>[
  visualUser(
    11,
    'hoangnam',
    'Nguyễn Hoàng Nam',
    email: 'nam.hoang@ttsmart.vn',
    phone: '0912 345 678',
    address: '12 Ngô Gia Tự, Long Biên, Hà Nội',
  ),
  visualUser(12, 'lantt', 'Trần Thị Lan'),
  visualUser(13, 'ducpm', 'Phạm Minh Đức'),
  visualUser(14, 'huylq', 'Lê Quốc Huy'),
  visualUser(15, 'havt', 'Vũ Thị Hà'),
  visualUser(16, 'tuandv', 'Đỗ Văn Tuấn'),
  visualUser(17, 'maibt', 'Bùi Thị Mai'),
];

Map<String, Object?> _role(
  int id,
  String code,
  String name,
  int users,
  int functions, {
  String? note,
}) => <String, Object?>{
  'id': id,
  'code': code,
  'name': name,
  'note': note,
  'levelRole': 2,
  'status': 1,
  'isActive': true,
  'userCount': users,
  'functionCount': 40,
  'grantedFunctionCount': functions,
};

final visualRoles = <Object?>[
  _role(
    1,
    'CONGTY2.0',
    'Chủ doanh nghiệp',
    8,
    34,
    note: 'Toàn quyền vận hành, không được xoá dữ liệu kế toán.',
  ),
  _role(2, 'QLTRAM', 'Quản lý trạm', 15, 22),
  _role(3, 'KETOAN', 'Kế toán', 6, 18),
  _role(4, 'NVBH', 'Nhân viên bán hàng', 42, 12),
  _role(5, 'KTV', 'Kỹ thuật viên', 19, 9),
  _role(6, 'LAIXE', 'Lái xe', 48, 4),
  _role(7, 'BAOVE', 'Bảo vệ', 9, 2),
];

Map<String, bool> _permissions(String key) => <String, bool>{
  'view': key[0] == '1',
  'create': key[1] == '1',
  'update': key[2] == '1',
  'delete': key[3] == '1',
  'import': key[4] == '1',
  'export': key[5] == '1',
  'print': key[6] == '1',
  'other': key[7] == '1',
  'dSach': key[8] == '1',
};

/// Groups (parents) + leaves of the role-function matrix (Figma S06).
const _matrix = <(int, int?, String, String?)>[
  (100, null, 'Hệ thống', null),
  (101, 100, 'Quản lý người dùng', '111001001'),
  (102, 100, 'Phân quyền', '111111111'),
  (103, 100, 'Quản lý chức năng', '100000001'),
  (200, null, 'Đơn hàng', null),
  (201, 200, 'Báo cáo đơn hàng', '111111111'),
  (202, 200, 'Thống kê đơn hàng', '100001101'),
  (300, null, 'Kho & vật tư', null),
  (301, 300, 'Quản lý kho', '000000000'),
  (302, 300, 'Quản lý chi phí', '101000001'),
];

Map<String, Object?> _matrixItem((int, int?, String, String?) row) {
  final key = row.$4 ?? '000000000';
  return <String, Object?>{
    'functionId': row.$1,
    'parentFunctionId': row.$2,
    'code': 'F${row.$1}',
    'name': row.$3,
    'url': row.$4 == null ? null : '/f/${row.$1}',
    'location': row.$1,
    'icon': null,
    'functionRoleId': key == '000000000' ? null : 900 + row.$1,
    'isAssigned': key != '000000000',
    'activeKey': key,
    'permissions': _permissions(key),
  };
}

Map<String, Object?> _roleDetail() => <String, Object?>{
  ...(visualRoles.first! as Map<String, Object?>),
  'functions': [
    for (var index = 0; index < 40; index++)
      <String, Object?>{
        'functionRoleId': 500 + index,
        'functionId': 1000 + index,
        'parentFunctionId': null,
        'code': 'F$index',
        'name': 'Chức năng $index',
        'url': '/f/$index',
        'location': index,
        'icon': null,
        'type': 1,
        'status': 1,
        'isActive': true,
        'activeKey': index < 34 ? '100000001' : '000000000',
        'permissions': _permissions(index < 34 ? '100000001' : '000000000'),
      },
  ],
};

Map<String, Object?> _node(
  int id,
  String name, {
  String? url,
  List<Object?> children = const [],
}) => <String, Object?>{
  'id': id,
  'parentFunctionId': null,
  'code': 'F$id',
  'name': name,
  'url': url,
  'note': null,
  'location': id,
  'icon': null,
  'status': 1,
  'isActive': true,
  'assignedRoleCount': 3,
  'grantedRoleCount': 2,
  'children': children,
};

List<Object?> _leaves(int parent, int count) => [
  for (var index = 1; index <= count; index++)
    _node(parent * 10 + index, 'Mục ${parent * 10 + index}', url: '/m/$index'),
];

final visualFunctionTree = <Object?>[
  _node(1, 'Hệ thống', children: _leaves(1, 3)),
  _node(2, 'Đơn hàng', children: _leaves(2, 2)),
  _node(3, 'Kho & vật tư', children: _leaves(3, 2)),
  _node(4, 'Báo cáo', children: _leaves(4, 4)),
  _node(5, 'Bảng giá', url: '/price'),
  _node(6, 'Cấu hình chung', url: '/setting'),
];

Map<String, Object?> visualFunction(
  int id,
  String code,
  String name, {
  int? parent,
  String? url,
  int? location,
  int children = 0,
}) => <String, Object?>{
  'id': id,
  'parentFunctionId': parent,
  'code': code,
  'name': name,
  'url': url,
  'location': location,
  'status': 1,
  'isActive': true,
  'childCount': children,
  'assignedRoleCount': 3,
  'grantedRoleCount': 2,
};

final visualFunctions = <Object?>[
  for (var index = 1; index <= 34; index++)
    visualFunction(index, 'F$index', 'Chức năng $index'),
];

final visualStations = <Object?>[
  for (final (id, name) in const [
    (31, 'Trạm Long Biên'),
    (32, 'Trạm Gia Lâm'),
    (33, 'Trạm Đông Anh'),
    (34, 'Trạm Hoài Đức'),
    (35, 'Trạm Thanh Trì'),
    (36, 'Trạm Sóc Sơn'),
  ])
    <String, Object?>{'id': id, 'name': name, 'phone': null},
];

/// Base routes; screens add their own in front via [extra]. Keys are
/// `METHOD /path` where the path is a regular expression.
ApiClient visualApiClient([Map<String, VisualRoute> extra = const {}]) {
  final routes = <String, VisualRoute>{
    r'GET /api/users/assignable-roles': (_) => visualRoles,
    r'GET /api/users/\d+': (request) {
      final id = int.parse(request.url.pathSegments.last);
      return visualUsers.firstWhere(
        (user) => (user! as Map<String, Object?>)['id'] == id,
        orElse: () => visualUsers.first,
      );
    },
    r'GET /api/users': (_) => _page(visualUsers, total: 147),
    r'GET /api/roles/\d+/function-matrix': (_) => [
      for (final row in _matrix) _matrixItem(row),
    ],
    r'GET /api/roles/\d+': (_) => _roleDetail(),
    r'GET /api/roles': (_) => _page(visualRoles, total: 12),
    r'GET /api/functions/tree': (_) => visualFunctionTree,
    r'GET /api/functions': (_) => visualFunctions,
    r'GET /api/functions/\d+': (_) =>
        visualFunction(5, 'BANGGIA', 'Bảng giá', url: '/price', location: 5),
    r'GET /api/branches': (_) => _page(visualStations),
    // Test-specific routes replace the defaults above.
    ...extra,
  };
  final compiled = [
    for (final entry in routes.entries)
      (RegExp('^${entry.key}\$'), entry.value),
  ];
  return ApiClient(
    baseUri: Uri.parse('http://localhost:5052'),
    timeout: const Duration(seconds: 1),
    httpClient: MockClient((request) async {
      final key = '${request.method} ${request.url.path}';
      for (final (pattern, route) in compiled) {
        if (pattern.hasMatch(key)) {
          // Routes may return a Future (e.g. one that never completes).
          final body = await Future<Object?>.value(route(request));
          return http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
      }
      return http.Response(jsonEncode({'message': 'No fixture for $key'}), 404);
    }),
  )..accessToken = 'visual-token';
}
