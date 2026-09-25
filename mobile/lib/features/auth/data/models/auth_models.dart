import '../../../../core/network/json_helpers.dart';
import '../../../access_management/data/models/permission_models.dart';

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.code,
    required this.phone,
    required this.companyId,
    required this.departmentId,
    required this.positionId,
    required this.unitId,
    required this.branchId,
    required this.status,
  });

  factory AuthenticatedUser.fromJson(Object? value) {
    final json = requireJsonObject(value, 'user');
    return AuthenticatedUser(
      id: requireInt(json, 'id'),
      userName: requireString(json, 'userName'),
      fullName: optionalString(json, 'fullName'),
      email: optionalString(json, 'email'),
      code: optionalString(json, 'code'),
      phone: optionalString(json, 'phone'),
      companyId: optionalInt(json, 'companyId'),
      departmentId: optionalInt(json, 'departmentId'),
      positionId: optionalInt(json, 'positionId'),
      unitId: optionalInt(json, 'unitId'),
      branchId: optionalString(json, 'branchId'),
      status: requireInt(json, 'status'),
    );
  }

  final int id;
  final String userName;
  final String? fullName;
  final String? email;
  final String? code;
  final String? phone;
  final int? companyId;
  final int? departmentId;
  final int? positionId;
  final int? unitId;
  final String? branchId;
  final int status;

  bool get isActive => status == 1;

  String get displayName {
    final value = fullName?.trim();
    return value == null || value.isEmpty ? userName : value;
  }
}

class AuthRole {
  const AuthRole({
    required this.id,
    required this.code,
    required this.name,
    required this.levelRole,
  });

  factory AuthRole.fromJson(Object? value) {
    final json = requireJsonObject(value, 'role');
    return AuthRole(
      id: requireInt(json, 'id'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      levelRole: optionalInt(json, 'levelRole'),
    );
  }

  final int id;
  final String code;
  final String name;
  final int? levelRole;
}

class GrantedFunction {
  const GrantedFunction({
    required this.id,
    required this.parentFunctionId,
    required this.code,
    required this.name,
    required this.url,
    required this.location,
    required this.icon,
    required this.activeKey,
    required this.permissions,
  });

  factory GrantedFunction.fromJson(Object? value) {
    final json = requireJsonObject(value, 'function');
    final permissions = _parsePermissions(json);
    return GrantedFunction(
      id: requireInt(json, 'id'),
      parentFunctionId: optionalInt(json, 'parentFunctionId'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      url: optionalString(json, 'url'),
      location: optionalInt(json, 'location'),
      icon: optionalString(json, 'icon'),
      activeKey: permissions.activeKey,
      permissions: permissions,
    );
  }

  final int id;
  final int? parentFunctionId;
  final String code;
  final String name;
  final String? url;
  final int? location;
  final String? icon;
  final String activeKey;
  final PermissionSet permissions;
}

class AuthRoleFunction {
  const AuthRoleFunction({
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.functionRoleId,
    required this.functionId,
    required this.parentFunctionId,
    required this.functionCode,
    required this.functionName,
    required this.url,
    required this.type,
    required this.activeKey,
    required this.permissions,
  });

  factory AuthRoleFunction.fromJson(Object? value) {
    final json = requireJsonObject(value, 'roleFunction');
    final permissions = _parsePermissions(json);
    return AuthRoleFunction(
      roleId: requireInt(json, 'roleId'),
      roleCode: requireString(json, 'roleCode'),
      roleName: requireString(json, 'roleName'),
      functionRoleId: requireInt(json, 'functionRoleId'),
      functionId: requireInt(json, 'functionId'),
      parentFunctionId: optionalInt(json, 'parentFunctionId'),
      functionCode: requireString(json, 'functionCode'),
      functionName: requireString(json, 'functionName'),
      url: optionalString(json, 'url'),
      type: optionalInt(json, 'type'),
      activeKey: permissions.activeKey,
      permissions: permissions,
    );
  }

  final int roleId;
  final String roleCode;
  final String roleName;
  final int functionRoleId;
  final int functionId;
  final int? parentFunctionId;
  final String functionCode;
  final String functionName;
  final String? url;
  final int? type;
  final String activeKey;
  final PermissionSet permissions;
}

class CurrentSession {
  const CurrentSession({
    required this.user,
    required this.roles,
    required this.functions,
    required this.roleFunctions,
  });

  factory CurrentSession.fromJson(Object? value) {
    final json = requireJsonObject(value, 'phiên đăng nhập');
    return CurrentSession(
      user: AuthenticatedUser.fromJson(json['user']),
      roles: requireJsonList(
        json['roles'],
        'roles',
      ).map(AuthRole.fromJson).toList(growable: false),
      functions: requireJsonList(
        json['functions'],
        'functions',
      ).map(GrantedFunction.fromJson).toList(growable: false),
      roleFunctions: requireJsonList(
        json['roleFunctions'],
        'roleFunctions',
      ).map(AuthRoleFunction.fromJson).toList(growable: false),
    );
  }

  final AuthenticatedUser user;
  final List<AuthRole> roles;
  final List<GrantedFunction> functions;
  final List<AuthRoleFunction> roleFunctions;
  GrantedFunction? functionByCode(String code) {
    final normalized = code.toUpperCase();
    for (final item in functions) {
      if (item.code.toUpperCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  bool hasPermission(String functionCode, AccessPermission permission) =>
      functionByCode(functionCode)?.permissions.allows(permission) ?? false;

  bool hasRole(String roleCode) {
    final normalized = roleCode.toUpperCase();
    return roles.any((role) => role.code.toUpperCase() == normalized);
  }

  bool hasAnyPermission(
    Iterable<String> functionCodes,
    AccessPermission permission,
  ) => functionCodes.any((code) => hasPermission(code, permission));
}

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.expiresAtUtc,
    required this.session,
  });

  factory LoginResult.fromJson(Object? value) {
    final json = requireJsonObject(value, 'kết quả đăng nhập');
    return LoginResult(
      accessToken: requireString(json, 'accessToken'),
      expiresAtUtc: requireUtcDateTime(json, 'expiresAtUtc'),
      session: CurrentSession.fromJson(json),
    );
  }

  final String accessToken;
  final DateTime expiresAtUtc;
  final CurrentSession session;
}

PermissionSet _parsePermissions(Map<String, dynamic> json) {
  return PermissionSet.fromContract(
    activeKey: json['activeKey'],
    permissions: json['permissions'],
  );
}
