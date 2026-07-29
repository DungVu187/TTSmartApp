import '../../../../core/network/json_helpers.dart';

abstract final class CompanyDataStatus {
  static const int active = 1;
  static const int deleted = 99;

  static bool isSupported(int? value) =>
      value == null || value == active || value == deleted;
}

enum CompanyPlan {
  free(0, 'Miễn phí'),
  paid(1, 'Trả phí');

  const CompanyPlan(this.value, this.label);

  final int value;
  final String label;

  static CompanyPlan fromValue(int value) => switch (value) {
    0 => CompanyPlan.free,
    1 => CompanyPlan.paid,
    _ => throw FormatException('active chỉ nhận giá trị 0 hoặc 1.'),
  };
}

class CompanyPage {
  const CompanyPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory CompanyPage.fromJson(Object? value) {
    final json = requireJsonObject(value, 'response phân trang công ty');
    return CompanyPage(
      items: requireJsonList(
        json['items'],
        'items',
      ).map(CompanyResponse.fromJson).toList(growable: false),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
    );
  }

  final List<CompanyResponse> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}

class CompanyResponse {
  const CompanyResponse({
    required this.id,
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.fax,
    required this.representative,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.userId,
    required this.status,
    required this.isActive,
    required this.countUser,
    required this.plan,
    required this.isLocked,
    required this.note,
    required this.logo,
    required this.expiredDate,
  });

  factory CompanyResponse.fromJson(Object? value) {
    final json = requireJsonObject(value, 'company');
    return CompanyResponse(
      id: requireInt(json, 'id'),
      code: optionalString(json, 'code'),
      name: optionalString(json, 'name'),
      email: optionalString(json, 'email'),
      phone: optionalString(json, 'phone'),
      address: optionalString(json, 'address'),
      fax: optionalString(json, 'fax'),
      representative: optionalString(json, 'representative'),
      contactName: optionalString(json, 'contactName'),
      contactEmail: optionalString(json, 'contactEmail'),
      contactPhone: optionalString(json, 'contactPhone'),
      createdAtUtc: optionalUtcDateTime(json, 'createdAtUtc'),
      updatedAtUtc: optionalUtcDateTime(json, 'updatedAtUtc'),
      userId: optionalInt(json, 'userId'),
      status: requireInt(json, 'status'),
      isActive: requireBool(json, 'isActive'),
      countUser: requireInt(json, 'countUser'),
      plan: CompanyPlan.fromValue(requireInt(json, 'active')),
      isLocked: requireBool(json, 'isLocked'),
      note: optionalString(json, 'note'),
      logo: optionalString(json, 'logo'),
      expiredDate: _optionalDate(json, 'expiredDate'),
    );
  }

  final int id;
  final String? code;
  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? fax;
  final String? representative;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;
  final int? userId;
  final int status;
  final bool isActive;
  final int countUser;
  final CompanyPlan plan;
  final bool isLocked;
  final String? note;
  final String? logo;
  final DateTime? expiredDate;

  String get displayName {
    final normalizedName = name?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }
    final normalizedCode = code?.trim();
    return normalizedCode == null || normalizedCode.isEmpty
        ? 'Công ty #$id'
        : normalizedCode;
  }

  bool get isDeleted => status == CompanyDataStatus.deleted;

  bool get hasLogo => logo?.trim().isNotEmpty == true;
}

class CompanyUpsertRequest {
  const CompanyUpsertRequest({
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.countUser,
    required this.plan,
    this.address,
    this.fax,
    this.representative,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.note,
  });

  final String code;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? fax;
  final String? representative;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final int countUser;
  final CompanyPlan plan;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'fax': fax,
    'representative': representative,
    'contactName': contactName,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'countUser': countUser,
    'active': plan.value,
    'note': note,
  };
}

class SetCompanyLockRequest {
  const SetCompanyLockRequest({required this.isLocked});

  final bool isLocked;

  Map<String, Object?> toJson() => <String, Object?>{'isLocked': isLocked};
}

class SetCompanyExpirationRequest {
  const SetCompanyExpirationRequest({required this.expiredDate});

  final DateTime? expiredDate;

  Map<String, Object?> toJson() => <String, Object?>{
    'expiredDate': expiredDate == null ? null : formatApiDate(expiredDate!),
  };
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key phải là ngày yyyy-MM-dd hoặc null.');
  }
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('$key phải là ngày yyyy-MM-dd hoặc null.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('$key không phải ngày hợp lệ.');
  }
  return parsed;
}

String formatApiDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
}
