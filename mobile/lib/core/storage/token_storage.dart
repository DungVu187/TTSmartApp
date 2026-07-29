import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession({required this.accessToken, required this.expiresAtUtc});

  final String accessToken;
  final DateTime expiresAtUtc;
}

abstract interface class TokenStorage {
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth.accessToken';
  static const _expiryKey = 'auth.expiresAtUtc';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final values = await Future.wait<String?>([
      _storage.read(key: _tokenKey),
      _storage.read(key: _expiryKey),
    ]);
    final token = values[0];
    final expiry = DateTime.tryParse(values[1] ?? '');
    if (token == null || token.isEmpty || expiry == null) {
      if (token != null || values[1] != null) {
        await clear();
      }
      return null;
    }
    return StoredSession(accessToken: token, expiresAtUtc: expiry.toUtc());
  }

  @override
  Future<void> write(StoredSession session) async {
    try {
      await _storage.write(key: _tokenKey, value: session.accessToken);
      await _storage.write(
        key: _expiryKey,
        value: session.expiresAtUtc.toUtc().toIso8601String(),
      );
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  @override
  Future<void> clear() => _storage.deleteAll();
}
