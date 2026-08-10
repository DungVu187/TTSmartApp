import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../access_management/data/repositories/access_management_repository.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

enum SessionStatus {
  initializing,
  recoveryRequired,
  unauthenticated,
  authenticated,
}

class AppController extends ChangeNotifier {
  AppController({
    required this.apiClient,
    required this.authRepository,
    required this.accessManagementRepository,
    required this.tokenStorage,
  }) {
    apiClient.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient apiClient;
  final AuthRepository authRepository;
  final AccessManagementRepository accessManagementRepository;
  final TokenStorage tokenStorage;

  SessionStatus _status = SessionStatus.initializing;
  CurrentSession? _session;
  ApiException? _startupError;
  ApiException? _loginError;
  String? _notice;
  bool _isLoginSubmitting = false;
  bool _isLoggingOut = false;

  SessionStatus get status => _status;
  CurrentSession? get session => _session;
  ApiException? get startupError => _startupError;
  ApiException? get loginError => _loginError;
  String? get notice => _notice;
  bool get isLoginSubmitting => _isLoginSubmitting;

  Future<void> initialize() async {
    _status = SessionStatus.initializing;
    _startupError = null;
    notifyListeners();

    try {
      final stored = await tokenStorage.read();
      if (stored == null) {
        _status = SessionStatus.unauthenticated;
        notifyListeners();
        return;
      }
      if (!stored.expiresAtUtc.isAfter(DateTime.now().toUtc())) {
        await _clearSessionStorage();
        _notice = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        _status = SessionStatus.unauthenticated;
        notifyListeners();
        return;
      }

      apiClient.accessToken = stored.accessToken;
      _session = await authRepository.getCurrentSession();
      _status = SessionStatus.authenticated;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.type == ApiFailureType.unauthorized) {
        return;
      }
      _startupError = error;
      _status = SessionStatus.recoveryRequired;
      notifyListeners();
    } catch (_) {
      _startupError = ApiException.storage();
      _status = SessionStatus.recoveryRequired;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String userName,
    required String password,
  }) async {
    if (_isLoginSubmitting) {
      return false;
    }
    _isLoginSubmitting = true;
    _loginError = null;
    _notice = null;
    notifyListeners();

    try {
      final result = await authRepository.login(
        userName: userName.trim(),
        password: password,
      );
      await tokenStorage.write(
        StoredSession(
          accessToken: result.accessToken,
          expiresAtUtc: result.expiresAtUtc,
        ),
      );
      apiClient.accessToken = result.accessToken;
      _session = result.session;
      _status = SessionStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      _loginError = error;
      return false;
    } catch (_) {
      apiClient.accessToken = null;
      await _clearSessionStorage();
      _loginError = ApiException.storage();
      return false;
    } finally {
      _isLoginSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentSession() async {
    _session = await authRepository.getCurrentSession();
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => authRepository.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  Future<void> logout() async {
    if (_isLoggingOut) {
      return;
    }
    _isLoggingOut = true;
    _notice = null;
    try {
      await authRepository.logout();
    } on ApiException catch (error) {
      if (error.type != ApiFailureType.unauthorized) {
        _notice =
            'Đã đăng xuất khỏi thiết bị, nhưng máy chủ chưa xác nhận thu hồi phiên.';
      }
    } catch (_) {
      _notice =
          'Đã đăng xuất khỏi thiết bị, nhưng máy chủ chưa xác nhận thu hồi phiên.';
    } finally {
      await _clearSessionStorage();
      _status = SessionStatus.unauthenticated;
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  Future<void> discardStoredSession() async {
    await _clearSessionStorage();
    _startupError = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  void clearLoginError() {
    if (_loginError == null) {
      return;
    }
    _loginError = null;
    notifyListeners();
  }

  bool hasPermission(String functionCode, AccessPermission permission) =>
      _session?.hasPermission(functionCode, permission) ?? false;

  bool hasRole(String roleCode) => _session?.hasRole(roleCode) ?? false;

  bool hasAnyPermission(
    Iterable<String> functionCodes,
    AccessPermission permission,
  ) => _session?.hasAnyPermission(functionCodes, permission) ?? false;

  Future<void> _handleUnauthorized() async {
    await _clearSessionStorage();
    _notice = 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _clearSessionStorage() async {
    apiClient.accessToken = null;
    _session = null;
    try {
      await tokenStorage.clear();
    } catch (_) {
      // Trạng thái trong bộ nhớ vẫn phải được xóa để token không tiếp tục dùng.
    }
  }

  @override
  void dispose() {
    apiClient.close();
    super.dispose();
  }
}
