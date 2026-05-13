import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'chatgpt2api.bearerToken';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token.trim());
  }

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
