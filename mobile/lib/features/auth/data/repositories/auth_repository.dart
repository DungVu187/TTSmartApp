import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/auth_models.dart';

class AuthRepository {
  const AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResult> login({
    required String userName,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/login',
      authenticated: false,
      body: <String, Object?>{'userName': userName, 'password': password},
    );
    return _parse(() => LoginResult.fromJson(response));
  }

  Future<CurrentSession> getCurrentSession() async {
    final response = await _apiClient.get('/api/auth/me');
    return _parse(() => CurrentSession.fromJson(response));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/api/auth/change-password',
      body: <String, Object?>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> logout() async {
    await _apiClient.post('/api/auth/logout');
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }
}
