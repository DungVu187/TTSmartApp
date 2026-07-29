Map<String, dynamic> requireJsonObject(Object? value, String context) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$context phải là một JSON object.');
}

List<Object?> requireJsonList(Object? value, String context) {
  if (value is List) {
    return value.cast<Object?>();
  }
  throw FormatException('$context phải là một JSON array.');
}

String requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('$key phải là chuỗi.');
}

String? optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$key phải là chuỗi hoặc null.');
}

int requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$key phải là số nguyên.');
}

int? optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$key phải là số nguyên hoặc null.');
}

bool requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key phải là boolean.');
}

bool? optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw FormatException('$key phải là boolean hoặc null.');
}

DateTime requireUtcDateTime(Map<String, dynamic> json, String key) {
  final value = requireString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key phải là thời gian ISO 8601.');
  }
  return parsed.toUtc();
}

DateTime? optionalUtcDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key phải là thời gian ISO 8601 hoặc null.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key phải là thời gian ISO 8601 hoặc null.');
  }
  return parsed.toUtc();
}
