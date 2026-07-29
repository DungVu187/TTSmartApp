import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_exception.dart';
import 'problem_details.dart';

typedef UnauthorizedCallback = Future<void> Function();

class ApiClient {
  ApiClient({
    required this.baseUri,
    required this.timeout,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final Duration timeout;
  final http.Client _httpClient;

  String? accessToken;
  UnauthorizedCallback? onUnauthorized;

  Future<Object?> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool authenticated = true,
  }) => _send('GET', path, query: query, authenticated: authenticated);

  Future<Uint8List> getBytes(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
  }) async {
    final request = http.Request('GET', _buildUri(path, query))
      ..headers['Accept'] = 'image/*';
    final response = await _execute(request, authenticated: true);
    return response.bodyBytes;
  }

  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<Object?> postMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path, const {}))
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );
    final response = await _execute(request, authenticated: true);
    return _decodeSuccess(response);
  }

  Future<Object?> put(String path, {Object? body}) =>
      _send('PUT', path, body: body, authenticated: true);

  Future<Object?> delete(String path) =>
      _send('DELETE', path, authenticated: true);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    Object? body,
    required bool authenticated,
  }) async {
    final request = http.Request(method, _buildUri(path, query))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final response = await _execute(request, authenticated: authenticated);
    try {
      return _decodeSuccess(response);
    } on FormatException {
      throw ApiException.invalidResponse();
    }
  }

  Future<http.Response> _execute(
    http.BaseRequest request, {
    required bool authenticated,
  }) async {
    if (authenticated) {
      final token = accessToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          type: ApiFailureType.unauthorized,
          message: 'Bạn chưa đăng nhập hoặc phiên đăng nhập đã hết hạn.',
          statusCode: 401,
        );
      }
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final streamed = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      final exception = _decodeFailure(response);
      if (response.statusCode == 401 && authenticated) {
        await onUnauthorized?.call();
      }
      throw exception;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        type: ApiFailureType.timeout,
        message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } on SocketException {
      throw const ApiException(
        type: ApiFailureType.network,
        message: 'Không thể kết nối máy chủ. Hãy kiểm tra mạng và địa chỉ API.',
      );
    } on http.ClientException {
      throw const ApiException(
        type: ApiFailureType.network,
        message: 'Không thể kết nối máy chủ. Hãy kiểm tra mạng và địa chỉ API.',
      );
    } catch (_) {
      throw const ApiException(
        type: ApiFailureType.unknown,
        message: 'Đã xảy ra lỗi ngoài dự kiến. Vui lòng thử lại.',
      );
    }
  }

  Uri _buildUri(String path, Map<String, Object?> query) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final queryParameters = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.toString().isNotEmpty) {
        queryParameters[entry.key] = value.toString();
      }
    }
    return baseUri.replace(
      path: normalizedPath,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Object? _decodeSuccess(http.Response response) {
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  ApiException _decodeFailure(http.Response response) {
    ProblemDetails? problem;
    if (response.bodyBytes.isNotEmpty) {
      try {
        problem = ProblemDetails.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } on FormatException {
        problem = null;
      }
    }

    final type = switch (response.statusCode) {
      400 => ApiFailureType.validation,
      401 => ApiFailureType.unauthorized,
      403 => ApiFailureType.forbidden,
      404 => ApiFailureType.notFound,
      409 => ApiFailureType.conflict,
      >= 500 => ApiFailureType.server,
      _ => ApiFailureType.unknown,
    };
    return ApiException(
      type: type,
      message: problem?.detail ?? _defaultMessage(type),
      statusCode: response.statusCode,
      title: problem?.title,
      traceId: problem?.traceId,
      fieldErrors: problem?.errors ?? const <String, List<String>>{},
    );
  }

  String _defaultMessage(ApiFailureType type) => switch (type) {
    ApiFailureType.validation => 'Dữ liệu gửi lên không hợp lệ.',
    ApiFailureType.unauthorized =>
      'Bạn chưa đăng nhập hoặc phiên đăng nhập đã hết hạn.',
    ApiFailureType.forbidden => 'Bạn không có quyền thực hiện chức năng này.',
    ApiFailureType.notFound => 'Không tìm thấy dữ liệu yêu cầu.',
    ApiFailureType.conflict => 'Dữ liệu đang bị xung đột.',
    ApiFailureType.server => 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.',
    _ => 'Yêu cầu không thành công. Vui lòng thử lại.',
  };

  void close() => _httpClient.close();
}
