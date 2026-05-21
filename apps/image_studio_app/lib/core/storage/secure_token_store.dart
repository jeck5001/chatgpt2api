import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> clearToken();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(mOptions: _macOptions);

  static const _tokenKey = 'chatgpt2api.bearerToken';

  // macOS defaults to kSecUseDataProtectionKeychain, which requires a real
  // Apple Developer team-signed bundle. Local ad-hoc builds fail with
  // "Unexpected security result code". Falling back to the legacy keychain
  // works for both ad-hoc and signed builds.
  static const _macOptions = MacOsOptions(usesDataProtectionKeychain: false);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token.trim());
  }

  @override
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
