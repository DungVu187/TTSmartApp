import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';

class _MemoryTokenStorage implements TokenStorage {
  StoredSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> write(StoredSession session) async => value = session;
}

void main() {
  test('logout gửi POST có Bearer token và nhận 204', () async {
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/logout');
        expect(request.headers['Authorization'], 'Bearer token-test');
        expect(request.body, isEmpty);
        return http.Response('', 204);
      }),
    )..accessToken = 'token-test';

    await AuthRepository(apiClient).logout();

    apiClient.close();
  });

  test('logout luôn xóa phiên local khi API lỗi', () async {
    final tokenStorage = _MemoryTokenStorage()
      ..value = StoredSession(
        accessToken: 'token-test',
        expiresAtUtc: DateTime.utc(2026, 7, 29),
      );
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"status":500,"detail":"Máy chủ đang bận."}',
          500,
          headers: const {'content-type': 'application/problem+json'},
        ),
      ),
    )..accessToken = 'token-test';
    final controller = AppController(
      apiClient: apiClient,
      authRepository: AuthRepository(apiClient),
      accessManagementRepository: AccessManagementRepository(apiClient),
      tokenStorage: tokenStorage,
    );

    await controller.logout();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.notice, contains('máy chủ chưa xác nhận'));
    expect(apiClient.accessToken, isNull);
    expect(tokenStorage.value, isNull);
    controller.dispose();
  });
}
