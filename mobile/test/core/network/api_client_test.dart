import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';

class _InspectingClient extends http.BaseClient {
  _InspectingClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}

void main() {
  test('GET can use a longer timeout for a heavy report', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(milliseconds: 10),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{"ok":true}', 200);
      }),
    )..accessToken = 'token-test';
    addTearDown(client.close);

    final response = await client.get(
      '/api/material-reports',
      requestTimeout: const Duration(milliseconds: 200),
    );

    expect(response, <String, dynamic>{'ok': true});
  });

  test('parse JSON thành công và gắn Bearer token', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/auth/me');
        expect(request.headers['Authorization'], 'Bearer token-test');
        return http.Response('{"ok":true}', 200);
      }),
    )..accessToken = 'token-test';

    final response = await client.get('/api/auth/me');

    expect(response, <String, dynamic>{'ok': true});
  });

  test('parse ValidationProblemDetails và field errors', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '{"title":"Dữ liệu không hợp lệ","status":400,'
            '"errors":{"UserName":["Tên đăng nhập là bắt buộc."]}}',
          ),
          400,
          headers: {'content-type': 'application/problem+json'},
        ),
      ),
    );

    final future = client.post(
      '/api/auth/login',
      authenticated: false,
      body: const <String, String>{},
    );

    await expectLater(
      future,
      throwsA(
        isA<ApiException>()
            .having((error) => error.type, 'type', ApiFailureType.validation)
            .having(
              (error) => error.fieldMessage('userName'),
              'userName error',
              'Tên đăng nhập là bắt buộc.',
            ),
      ),
    );
  });

  test('401 ở API bảo vệ gọi callback xóa phiên', () async {
    var callbackCount = 0;
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"status":401,"detail":"Token hết hạn."}'),
          401,
        ),
      ),
    )..accessToken = 'expired-token';
    client.onUnauthorized = () async => callbackCount++;

    await expectLater(
      client.get('/api/auth/me'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiFailureType.unauthorized,
        ),
      ),
    );
    expect(callbackCount, 1);
  });

  test('multipart request keeps auth and file content type', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: _InspectingClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/companies/12/logo');
        expect(request.headers['Authorization'], 'Bearer token-test');
        expect(request, isA<http.MultipartRequest>());
        final multipart = request as http.MultipartRequest;
        expect(multipart.files.single.field, 'file');
        expect(multipart.files.single.filename, 'logo.png');
        expect(multipart.files.single.contentType.mimeType, 'image/png');
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('{"ok":true}')),
          200,
        );
      }),
    )..accessToken = 'token-test';

    final response = await client.postMultipart(
      '/api/companies/12/logo',
      fieldName: 'file',
      bytes: [1, 2, 3],
      fileName: 'logo.png',
      contentType: 'image/png',
    );

    expect(response, <String, dynamic>{'ok': true});
  });
}
