import '../../../../core/network/json_helpers.dart';

class FunctionResponse {
  const FunctionResponse({
    required this.id,
    required this.parentFunctionId,
    required this.code,
    required this.name,
    required this.url,
    required this.note,
    required this.location,
    required this.icon,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.userId,
    required this.status,
    required this.isActive,
    required this.childCount,
    required this.assignedRoleCount,
    required this.grantedRoleCount,
  });

  factory FunctionResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'function response');
    return FunctionResponse(
      id: requireInt(json, 'id'),
      parentFunctionId: optionalInt(json, 'parentFunctionId'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      url: optionalString(json, 'url'),
      note: optionalString(json, 'note'),
      location: optionalInt(json, 'location'),
      icon: optionalString(json, 'icon'),
      createdAtUtc: optionalUtcDateTime(json, 'createdAtUtc'),
      updatedAtUtc: optionalUtcDateTime(json, 'updatedAtUtc'),
      userId: optionalInt(json, 'userId'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      childCount: requireInt(json, 'childCount'),
      assignedRoleCount: requireInt(json, 'assignedRoleCount'),
      grantedRoleCount: requireInt(json, 'grantedRoleCount'),
    );
  }

  final int id;
  final int? parentFunctionId;
  final String code;
  final String name;
  final String? url;
  final String? note;
  final int? location;
  final String? icon;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;
  final int? userId;
  final int status;
  final bool isActive;
  final int childCount;
  final int assignedRoleCount;
  final int grantedRoleCount;

  bool get isContainer => childCount > 0;
}

class FunctionTreeNodeResponse {
  const FunctionTreeNodeResponse({
    required this.id,
    required this.parentFunctionId,
    required this.code,
    required this.name,
    required this.url,
    required this.note,
    required this.location,
    required this.icon,
    required this.status,
    required this.isActive,
    required this.assignedRoleCount,
    required this.grantedRoleCount,
    required this.children,
  });

  factory FunctionTreeNodeResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'function tree node');
    return FunctionTreeNodeResponse(
      id: requireInt(json, 'id'),
      parentFunctionId: optionalInt(json, 'parentFunctionId'),
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      url: optionalString(json, 'url'),
      note: optionalString(json, 'note'),
      location: optionalInt(json, 'location'),
      icon: optionalString(json, 'icon'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      assignedRoleCount: requireInt(json, 'assignedRoleCount'),
      grantedRoleCount: requireInt(json, 'grantedRoleCount'),
      children: requireJsonList(
        json['children'],
        'children',
      ).map(FunctionTreeNodeResponse.fromJson).toList(growable: false),
    );
  }

  final int id;
  final int? parentFunctionId;
  final String code;
  final String name;
  final String? url;
  final String? note;
  final int? location;
  final String? icon;
  final int status;
  final bool isActive;
  final int assignedRoleCount;
  final int grantedRoleCount;
  final List<FunctionTreeNodeResponse> children;

  bool get isContainer => children.isNotEmpty;

  Iterable<FunctionTreeNodeResponse> flatten() sync* {
    yield this;
    for (final child in children) {
      yield* child.flatten();
    }
  }

  Set<int> descendantIds() => children
      .expand((child) => <int>{child.id, ...child.descendantIds()})
      .toSet();
}

class FunctionFieldsRequest {
  const FunctionFieldsRequest({
    required this.parentFunctionId,
    required this.code,
    required this.name,
    required this.url,
    required this.note,
    required this.location,
    required this.icon,
  });

  final int? parentFunctionId;
  final String code;
  final String name;
  final String? url;
  final String? note;
  final int? location;
  final String? icon;

  Map<String, Object?> toJson() => <String, Object?>{
    'parentFunctionId': parentFunctionId,
    'code': code,
    'name': name,
    'url': url,
    'note': note,
    'location': location,
    'icon': icon,
  };
}

class CreateFunctionRequest extends FunctionFieldsRequest {
  const CreateFunctionRequest({
    required super.parentFunctionId,
    required super.code,
    required super.name,
    required super.url,
    required super.note,
    required super.location,
    required super.icon,
  });
}

class UpdateFunctionRequest extends FunctionFieldsRequest {
  const UpdateFunctionRequest({
    required super.parentFunctionId,
    required super.code,
    required super.name,
    required super.url,
    required super.note,
    required super.location,
    required super.icon,
  });
}

class SetFunctionStatusRequest {
  const SetFunctionStatusRequest({required this.isActive});

  final bool isActive;

  Map<String, Object?> toJson() => <String, Object?>{'isActive': isActive};
}

List<FunctionTreeNodeResponse> parseFunctionTree(Object? value) =>
    requireJsonList(
      value,
      'function tree',
    ).map(FunctionTreeNodeResponse.fromJson).toList(growable: false);

List<FunctionResponse> parseFunctionList(Object? value) => requireJsonList(
  value,
  'functions',
).map(FunctionResponse.fromJson).toList(growable: false);
