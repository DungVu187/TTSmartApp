enum ApiFailureType {
  network,
  timeout,
  unauthorized,
  forbidden,
  validation,
  notFound,
  conflict,
  server,
  invalidResponse,
  storage,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.title,
    this.traceId,
    this.fieldErrors = const <String, List<String>>{},
  });

  factory ApiException.invalidResponse([String? detail]) => ApiException(
    type: ApiFailureType.invalidResponse,
    message: detail ?? 'Dữ liệu máy chủ trả về không đúng định dạng mong đợi.',
  );

  factory ApiException.storage([String? detail]) => ApiException(
    type: ApiFailureType.storage,
    message: detail ?? 'Không thể lưu phiên đăng nhập an toàn trên thiết bị.',
  );

  final ApiFailureType type;
  final String message;
  final int? statusCode;
  final String? title;
  final String? traceId;
  final Map<String, List<String>> fieldErrors;

  String? fieldMessage(String fieldName) {
    final normalized = fieldName.toLowerCase();
    for (final entry in fieldErrors.entries) {
      final key = entry.key.split('.').last.toLowerCase();
      if (key == normalized && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
