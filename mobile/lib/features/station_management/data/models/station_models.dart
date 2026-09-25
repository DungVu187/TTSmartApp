import '../../../../core/network/json_helpers.dart';

abstract final class StationDataStatus {
  static const int active = 1;
  static const int deleted = 99;

  static bool isSupported(int? value) =>
      value == null || value == active || value == deleted;
}

enum StationType {
  mixing(1, 'Trạm trộn'),
  scale(2, 'Trạm cân');

  const StationType(this.value, this.label);

  final int value;
  final String label;

  static StationType fromValue(int? value) => switch (value) {
    1 => StationType.mixing,
    2 => StationType.scale,
    _ => throw FormatException('typeTram chỉ nhận giá trị 1 hoặc 2.'),
  };
}

class StationPage {
  const StationPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory StationPage.fromJson(Object? value) {
    final json = requireJsonObject(value, 'response phân trang trạm');
    return StationPage(
      items: requireJsonList(
        json['items'],
        'items',
      ).map(StationListItem.fromJson).toList(growable: false),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
    );
  }

  final List<StationListItem> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}

class StationListItem {
  const StationListItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.typeTram,
  });

  factory StationListItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm trong danh sách');
    return StationListItem(
      id: requireInt(json, 'id'),
      name: optionalString(json, 'name'),
      phone: optionalString(json, 'phone'),
      typeTram: _optionalStationType(json),
    );
  }

  final int id;
  final String? name;
  final String? phone;
  final int? typeTram;

  String get displayName {
    final normalized = name?.trim();
    return normalized == null || normalized.isEmpty ? 'Trạm #$id' : normalized;
  }

  StationType? get type =>
      typeTram == null ? null : StationType.fromValue(typeTram);
}

class StationResponse {
  const StationResponse({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.code,
    required this.name,
    required this.avatar,
    required this.email,
    required this.phone,
    required this.address,
    required this.typeTram,
    required this.username,
    required this.password,
    required this.pmqlXe,
    required this.qlCamera,
    required this.status,
    required this.isActive,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory StationResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'chi tiết trạm');
    return StationResponse(
      id: requireInt(json, 'id'),
      companyId: optionalInt(json, 'companyId'),
      companyName: optionalString(json, 'companyName'),
      code: optionalString(json, 'code'),
      name: optionalString(json, 'name'),
      avatar: optionalString(json, 'avatar'),
      email: optionalString(json, 'email'),
      phone: optionalString(json, 'phone'),
      address: optionalString(json, 'address'),
      typeTram: _optionalStationType(json),
      username: optionalString(json, 'username'),
      password: requireString(json, 'password'),
      pmqlXe: optionalString(json, 'pmqlXe'),
      qlCamera: optionalString(json, 'qlCamera'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      createdAtUtc: optionalUtcDateTime(json, 'createdAtUtc'),
      updatedAtUtc: optionalUtcDateTime(json, 'updatedAtUtc'),
    );
  }

  final int id;
  final int? companyId;
  final String? companyName;
  final String? code;
  final String? name;
  final String? avatar;
  final String? email;
  final String? phone;
  final String? address;
  final int? typeTram;
  final String? username;
  final String password;
  final String? pmqlXe;
  final String? qlCamera;
  final int status;
  final bool isActive;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  String get displayName {
    final normalized = name?.trim();
    return normalized == null || normalized.isEmpty ? 'Trạm #$id' : normalized;
  }

  StationType? get type =>
      typeTram == null ? null : StationType.fromValue(typeTram);

  bool get isDeleted => status == StationDataStatus.deleted;
}

int? _optionalStationType(Map<String, dynamic> json) {
  final value = optionalInt(json, 'typeTram');
  if (value != null) StationType.fromValue(value);
  return value;
}

class CreateStationRequest {
  const CreateStationRequest({
    required this.companyId,
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.username,
    required this.password,
    required this.typeTram,
    this.address,
    this.pmqlXe,
    this.qlCamera,
  });

  final int companyId;
  final String code;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String username;
  final String password;
  final String? pmqlXe;
  final String? qlCamera;
  final int typeTram;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'companyId': companyId,
    'code': code,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'username': username,
    'password': password,
    'pmqlXe': pmqlXe,
    'qlCamera': qlCamera,
    'typeTram': typeTram,
  };
}

class UpdateStationRequest {
  const UpdateStationRequest({
    this.companyId,
    this.code,
    this.name,
    this.email,
    this.phone,
    this.address,
    this.username,
    this.password,
    this.pmqlXe,
    this.qlCamera,
    this.typeTram,
  });

  final int? companyId;
  final String? code;
  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? username;
  final String? password;
  final String? pmqlXe;
  final String? qlCamera;
  final int? typeTram;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (companyId != null) 'companyId': companyId,
    if (code != null) 'code': code,
    if (name != null) 'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (username != null) 'username': username,
    if (password != null) 'password': password,
    if (pmqlXe != null) 'pmqlXe': pmqlXe,
    if (qlCamera != null) 'qlCamera': qlCamera,
    if (typeTram != null) 'typeTram': typeTram,
  };
}
