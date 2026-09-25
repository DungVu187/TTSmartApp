import '../../../../core/network/json_helpers.dart';

class RoleReferenceResponse {
  const RoleReferenceResponse({
    required this.id,
    required this.code,
    required this.name,
    required this.levelRole,
    required this.status,
  });

  factory RoleReferenceResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'role reference');
    return RoleReferenceResponse(
      id: requireInt(json, 'id'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      levelRole: optionalInt(json, 'levelRole'),
      status: requireInt(json, 'status'),
    );
  }

  final int id;
  final String code;
  final String name;
  final int? levelRole;
  final int status;

  bool get isActive => status == 1;
}

class UserResponse {
  const UserResponse({
    required this.id,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.code,
    required this.avata,
    required this.unitId,
    required this.positionId,
    required this.departmentId,
    required this.companyId,
    required this.address,
    required this.phone,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.tokenSinceUtc,
    required this.regEmail,
    required this.roleMax,
    required this.roleLevel,
    required this.isRoleGroup,
    required this.userCreateId,
    required this.userEditId,
    required this.status,
    required this.isActive,
    required this.branchId,
    required this.roles,
  });

  factory UserResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'user response');
    return UserResponse(
      id: requireInt(json, 'id'),
      userName: requireString(json, 'userName'),
      fullName: optionalString(json, 'fullName'),
      email: optionalString(json, 'email'),
      code: optionalString(json, 'code'),
      avata: optionalString(json, 'avata'),
      unitId: optionalInt(json, 'unitId'),
      positionId: optionalInt(json, 'positionId'),
      departmentId: optionalInt(json, 'departmentId'),
      companyId: optionalInt(json, 'companyId'),
      address: optionalString(json, 'address'),
      phone: optionalString(json, 'phone'),
      createdAtUtc: optionalUtcDateTime(json, 'createdAtUtc'),
      updatedAtUtc: optionalUtcDateTime(json, 'updatedAtUtc'),
      tokenSinceUtc: optionalUtcDateTime(json, 'tokenSinceUtc'),
      regEmail: optionalString(json, 'regEmail'),
      roleMax: optionalInt(json, 'roleMax'),
      roleLevel: optionalInt(json, 'roleLevel'),
      isRoleGroup: optionalBool(json, 'isRoleGroup'),
      userCreateId: optionalInt(json, 'userCreateId'),
      userEditId: optionalInt(json, 'userEditId'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      branchId: optionalString(json, 'branchId'),
      roles: requireJsonList(
        json['roles'],
        'roles',
      ).map(RoleReferenceResponse.fromJson).toList(growable: false),
    );
  }

  final int id;
  final String userName;
  final String? fullName;
  final String? email;
  final String? code;
  final String? avata;
  final int? unitId;
  final int? positionId;
  final int? departmentId;
  final int? companyId;
  final String? address;
  final String? phone;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;
  final DateTime? tokenSinceUtc;
  final String? regEmail;
  final int? roleMax;
  final int? roleLevel;
  final bool? isRoleGroup;
  final int? userCreateId;
  final int? userEditId;
  final int status;
  final bool isActive;
  final String? branchId;
  final List<RoleReferenceResponse> roles;

  String get displayName {
    final value = fullName?.trim();
    return value == null || value.isEmpty ? userName : value;
  }
}

class UserFields {
  const UserFields({
    required this.userName,
    this.fullName,
    this.email,
    this.code,
    this.regEmail,
    this.address,
    this.phone,
    this.unitId,
    this.positionId,
    this.departmentId,
    this.companyId,
    this.roleMax,
    this.roleLevel,
    this.isRoleGroup,
    this.branchId,
  });

  final String userName;
  final String? fullName;
  final String? email;
  final String? code;
  final String? regEmail;
  final String? address;
  final String? phone;
  final int? unitId;
  final int? positionId;
  final int? departmentId;
  final int? companyId;
  final int? roleMax;
  final int? roleLevel;
  final bool? isRoleGroup;
  final String? branchId;

  Map<String, Object?> toJson() => <String, Object?>{
    'userName': userName,
    'fullName': fullName,
    'email': email,
    'code': code,
    'regEmail': regEmail,
    'address': address,
    'phone': phone,
    'unitId': unitId,
    'positionId': positionId,
    'departmentId': departmentId,
    'companyId': companyId,
    'roleMax': roleMax,
    'roleLevel': roleLevel,
    'isRoleGroup': isRoleGroup,
    'branchId': branchId,
  };
}

class CreateUserRequest extends UserFields {
  const CreateUserRequest({
    required super.userName,
    required this.password,
    required this.roleIds,
    super.fullName,
    super.email,
    super.code,
    super.regEmail,
    super.address,
    super.phone,
    super.unitId,
    super.positionId,
    super.departmentId,
    super.companyId,
    super.roleMax,
    super.roleLevel,
    super.isRoleGroup,
    super.branchId,
  });

  final String password;
  final List<int> roleIds;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'password': password,
    'roleIds': roleIds,
  };
}

class UpdateUserRequest extends UserFields {
  const UpdateUserRequest({
    required super.userName,
    this.roleIds,
    super.fullName,
    super.email,
    super.code,
    super.regEmail,
    super.address,
    super.phone,
    super.unitId,
    super.positionId,
    super.departmentId,
    super.companyId,
    super.roleMax,
    super.roleLevel,
    super.isRoleGroup,
    super.branchId,
  });

  final List<int>? roleIds;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'roleIds': roleIds,
  };
}

class SetUserStatusRequest {
  const SetUserStatusRequest({required this.isActive});

  final bool isActive;

  Map<String, Object?> toJson() => <String, Object?>{'isActive': isActive};
}

class SetUserRolesRequest {
  const SetUserRolesRequest({required this.roleIds});

  final List<int> roleIds;

  Map<String, Object?> toJson() => <String, Object?>{'roleIds': roleIds};
}

class ResetPasswordRequest {
  const ResetPasswordRequest();

  Map<String, Object?> toJson() => const <String, Object?>{};
}
