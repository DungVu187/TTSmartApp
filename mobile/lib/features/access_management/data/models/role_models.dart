import '../../../../core/network/json_helpers.dart';
import 'permission_models.dart';

class RoleListItemResponse {
  const RoleListItemResponse({
    required this.id,
    required this.code,
    required this.name,
    required this.note,
    required this.levelRole,
    required this.status,
    required this.isActive,
    required this.userCount,
    required this.functionCount,
    required this.grantedFunctionCount,
  });

  factory RoleListItemResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'role list item');
    return RoleListItemResponse(
      id: requireInt(json, 'id'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      note: optionalString(json, 'note'),
      levelRole: optionalInt(json, 'levelRole'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      userCount: requireInt(json, 'userCount'),
      functionCount: requireInt(json, 'functionCount'),
      grantedFunctionCount: requireInt(json, 'grantedFunctionCount'),
    );
  }

  final int id;
  final String code;
  final String name;
  final String? note;
  final int? levelRole;
  final int status;
  final bool isActive;
  final int userCount;
  final int functionCount;
  final int grantedFunctionCount;
}

class RoleFunctionResponse {
  const RoleFunctionResponse({
    required this.functionRoleId,
    required this.functionId,
    required this.parentFunctionId,
    required this.code,
    required this.name,
    required this.url,
    required this.location,
    required this.icon,
    required this.type,
    required this.activeKey,
    required this.permissions,
    required this.status,
    required this.isActive,
  });

  factory RoleFunctionResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'role function');
    final permissions = PermissionSet.fromContract(
      activeKey: json['activeKey'],
      permissions: json['permissions'],
    );
    return RoleFunctionResponse(
      functionRoleId: requireInt(json, 'functionRoleId'),
      functionId: requireInt(json, 'functionId'),
      parentFunctionId: optionalInt(json, 'parentFunctionId'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      url: optionalString(json, 'url'),
      location: optionalInt(json, 'location'),
      icon: optionalString(json, 'icon'),
      type: optionalInt(json, 'type'),
      activeKey: permissions.activeKey,
      permissions: permissions,
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
    );
  }

  final int functionRoleId;
  final int functionId;
  final int? parentFunctionId;
  final String code;
  final String name;
  final String? url;
  final int? location;
  final String? icon;
  final int? type;
  final String activeKey;
  final PermissionSet permissions;
  final int status;
  final bool isActive;
}

class RoleResponse {
  const RoleResponse({
    required this.id,
    required this.code,
    required this.name,
    required this.note,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.userEditId,
    required this.userId,
    required this.levelRole,
    required this.status,
    required this.isActive,
    required this.userCount,
    required this.functions,
  });

  factory RoleResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'role response');
    return RoleResponse(
      id: requireInt(json, 'id'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      note: optionalString(json, 'note'),
      createdAtUtc: optionalUtcDateTime(json, 'createdAtUtc'),
      updatedAtUtc: optionalUtcDateTime(json, 'updatedAtUtc'),
      userEditId: optionalInt(json, 'userEditId'),
      userId: optionalInt(json, 'userId'),
      levelRole: optionalInt(json, 'levelRole'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      userCount: requireInt(json, 'userCount'),
      functions: requireJsonList(
        json['functions'],
        'functions',
      ).map(RoleFunctionResponse.fromJson).toList(growable: false),
    );
  }

  final int id;
  final String code;
  final String name;
  final String? note;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;
  final int? userEditId;
  final int? userId;
  final int? levelRole;
  final int status;
  final bool isActive;
  final int userCount;
  final List<RoleFunctionResponse> functions;

  int get grantedFunctionCount =>
      functions.where((item) => !item.permissions.isEmpty).length;
}

class RoleFunctionMatrixItemResponse {
  const RoleFunctionMatrixItemResponse({
    required this.functionId,
    required this.parentFunctionId,
    required this.code,
    required this.name,
    required this.url,
    required this.location,
    required this.icon,
    required this.functionRoleId,
    required this.isAssigned,
    required this.activeKey,
    required this.permissions,
  });

  factory RoleFunctionMatrixItemResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'role function matrix item');
    final permissions = PermissionSet.fromContract(
      activeKey: json['activeKey'],
      permissions: json['permissions'],
    );
    return RoleFunctionMatrixItemResponse(
      functionId: requireInt(json, 'functionId'),
      parentFunctionId: optionalInt(json, 'parentFunctionId'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      url: optionalString(json, 'url'),
      location: optionalInt(json, 'location'),
      icon: optionalString(json, 'icon'),
      functionRoleId: optionalInt(json, 'functionRoleId'),
      isAssigned: requireBool(json, 'isAssigned'),
      activeKey: permissions.activeKey,
      permissions: permissions,
    );
  }

  final int functionId;
  final int? parentFunctionId;
  final String code;
  final String name;
  final String? url;
  final int? location;
  final String? icon;
  final int? functionRoleId;
  final bool isAssigned;
  final String activeKey;
  final PermissionSet permissions;

  RoleFunctionMatrixItemResponse withPermissions(PermissionSet value) =>
      RoleFunctionMatrixItemResponse(
        functionId: functionId,
        parentFunctionId: parentFunctionId,
        code: code,
        name: name,
        url: url,
        location: location,
        icon: icon,
        functionRoleId: functionRoleId,
        isAssigned: isAssigned || !value.isEmpty,
        activeKey: value.activeKey,
        permissions: value,
      );

  RoleFunctionMatrixItemResponse withAssignment(bool value) =>
      RoleFunctionMatrixItemResponse(
        functionId: functionId,
        parentFunctionId: parentFunctionId,
        code: code,
        name: name,
        url: url,
        location: location,
        icon: icon,
        functionRoleId: value ? functionRoleId : null,
        isAssigned: value,
        activeKey: value ? activeKey : PermissionSet.emptyActiveKey,
        permissions: value ? permissions : const PermissionSet.none(),
      );
}

class RoleFieldsRequest {
  const RoleFieldsRequest({
    required this.code,
    required this.name,
    this.note,
    this.levelRole,
  });

  final String code;
  final String name;
  final String? note;
  final int? levelRole;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'name': name,
    'note': note,
    'levelRole': levelRole,
  };
}

class CreateRoleRequest extends RoleFieldsRequest {
  const CreateRoleRequest({
    required super.code,
    required super.name,
    super.note,
    super.levelRole,
  });
}

class UpdateRoleRequest extends RoleFieldsRequest {
  const UpdateRoleRequest({
    required super.code,
    required super.name,
    super.note,
    super.levelRole,
  });
}

class SetRoleStatusRequest {
  const SetRoleStatusRequest({required this.isActive});

  final bool isActive;

  Map<String, Object?> toJson() => <String, Object?>{'isActive': isActive};
}

class RoleFunctionAssignmentRequest {
  RoleFunctionAssignmentRequest({
    required this.functionId,
    required String activeKey,
  }) : activeKey = PermissionSet.normalizeActiveKey(activeKey);

  factory RoleFunctionAssignmentRequest.fromPermissions({
    required int functionId,
    required PermissionSet permissions,
  }) => RoleFunctionAssignmentRequest(
    functionId: functionId,
    activeKey: permissions.activeKey,
  );

  final int functionId;
  final String activeKey;

  Map<String, Object?> toJson() => <String, Object?>{
    'functionId': functionId,
    'activeKey': activeKey,
  };
}

class SetRoleFunctionActiveKeyRequest {
  SetRoleFunctionActiveKeyRequest({required String activeKey})
    : activeKey = PermissionSet.normalizeActiveKey(activeKey);

  final String activeKey;

  Map<String, Object?> toJson() => <String, Object?>{'activeKey': activeKey};
}

class SetRoleFunctionsRequest {
  const SetRoleFunctionsRequest({required this.functions});

  final List<RoleFunctionAssignmentRequest> functions;

  Map<String, Object?> toJson() => <String, Object?>{
    'functions': functions.map((item) => item.toJson()).toList(growable: false),
  };
}
